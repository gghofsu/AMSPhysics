begin
  require 'fileutils'
rescue LoadError
  cfpath = __FILE__.dup
  cfpath.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
  dir = File.dirname(cfpath)
  Sketchup.require File.join(dir, 'thirdparty', 'fileutils')
end

module AMS
  # An extension manager for copying, loading, and removing dynamic linked
  # libraries, C extensions, and rubies. Thanks to ThomThom for allowing me to
  # extend his original C extension manager.
  # @since 3.5.0
  class ExtensionManager

    # Apply a staging technique to the dynamically linked libraries, to bypass
    # overwrite issues when updating the loaded extension.
    # 1. The files within <i>EXT_PATH/libraries/stage/</i> folder are used as
    #    resources for copying and are usually not loaded. These files are the
    #    ones that get overwritten when the extension is updated.
    # 2. Unless already created, the manager creates an additional
    #    version-specific folder within <i>EXT_PATH/libraries/</i> and copies
    #    the platform-specific, staged resources into the folder. The libraries
    #    within the version-specific folder are the ones that get loaded.
    # 3. In case the extension is installed outside the user directory, where the
    #    file permissions are limited, the necessary staged resources are copied
    #    into a TEMP folder and are loaded from there.
    # 4. If all fails, as the last resort, loading is performed from the staged
    #    directory.
    # 5. An optional clean-up method removes outdated version-specific folders,
    #    and unregistered rubies, for the purpose of keeping the plugin
    #    directory clean.
    # @note When the libraries are copied, they are obtained from
    #   <i>EXT_PATH/libraries/stage/</i>.
    # @note When the libraries are loaded, they are required from
    #   <i>EXT_PATH/libraries/VERSION/</i> or
    #   <i>TEMP_EXT_PATH/libraries/VERSION/</i> or
    #   <i>EXT_PATH/libraries/stage/</i> (as the last resort).
    # @note Rubies are loaded from <i>EXT_PATH</i>.
    # @param [String] ext_path A path to the extension.
    # @param [String] ext_version A version of the extension.
    # @param [Boolean] experimental The experimental option updates the
    #   libraries every time they are loaded. This is useful if the library is
    #   in development.
    # @example
    #   dir = File.dirname(__FILE__)
    #   base = File.basename(__FILE__)
    #   ext_manager = AMS::ExtensionManager.new(dir, "1.2.3")
    #   ext_manager.add_c_extension('my_lib')
    #   ext_manager.add_ruby('some_ruby_file_name')
    #   ext_manager.add_ruby('some_other_ruby_file_name')
    #   ext_manager.add_ruby_no_require(base)
    #   ext_manager.require_all
    #   ext_manager.clean_up(true)
    def initialize(ext_path, ext_version, experimental = false)
      @ext_path = ext_path.to_s.dup
      @ext_version = ext_version.to_s.dup
      @experimental = experimental ? true : false
      unless AMS::IS_RUBY_VERSION_18
        @ext_path.force_encoding('UTF-8')
        @ext_version.force_encoding('UTF-8')
      end
      if @ext_version.empty? || @ext_version.gsub(/[^A-Za-z0-9\.\-]/i, '') != @ext_version
        raise(IOError, "The given extension version, \"#{@ext_version}\", is invalid!")
      end
      unless ::File.directory?(@ext_path)
        raise(IOError, "The given extension path, \"#{@ext_path}\", is invalid!")
      end
      @ext_name = ::File.basename(@ext_path)
      @c_extensions = []
      @libraries = []
      @rubies = []
      @rubies_no_require = []
    end

    # Add an `.so`/`.bundle` file that must be copied/loaded.
    # @param [String] filename Library filename.
    # @note All C extension files are be copied from
    #   <i>EXT_PATH/libraries/stage/PLATFORM + BIT/RUBY_VERSION/</i>.
    # @return [void]
    def add_c_extension(filename)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      filename = File.basename(filename).gsub(/\.(so|bundle)$/, '')
      @c_extensions << filename
    end

    # Add a `.dll`/`.dylib` file that must be copied/loaded.
    # @param [String] filename Library filename.
    # @note All dll/dylib files are copied from
    #   <i>EXT_PATH/libraries/stage/PLATFORM + BIT/</i>.
    # @return [void]
    def add_required_library(filename)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      filename = File.basename(filename).gsub(/\.(dll|dylib)$/, '')
      @libraries << [filename, true]
    end


    # Add a library file that will be copied/loaded in case it's there.
    # @param [String] filename Library filename.
    # @note All dll/dylib files are copied from
    #   <i>EXT_PATH/libraries/stage/PLATFORM + BIT/</i>.
    # @return [void]
    def add_optional_library(filename)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      filename = File.basename(filename).gsub(/\.(dll|dylib)$/, '')
      @libraries << [filename, false]
    end

    # Get the Ruby ABI version of the running SketchUp, e.g. "3.2".
    # @return [String]
    # @since 3.8.0
    def ruby_abi_version
      RUBY_VERSION[0..2].to_s
    end

    # Get all Ruby ABI versions for which a build of the given c extension is
    # present in the stage directory.
    # @param [String] filename C extension filename.
    # @return [Array<String>]
    # @since 3.8.0
    def available_c_extension_abis(filename)
      filename = normalize_filename(filename)
      ops = AMS::IS_PLATFORM_WINDOWS ? 'win' : 'osx'
      bit = AMS::IS_SKETCHUP_64BIT ? '64' : '32'
      c_ext = AMS::IS_PLATFORM_WINDOWS ? '.so' : '.bundle'
      dir = ::File.join(@ext_path, 'libraries', 'stage', ops + bit)
      return [] unless ::File.directory?(dir)
      ::Dir.entries(dir).select { |entry|
        ::File.exist?(::File.join(dir, entry, filename + c_ext))
      }.sort
    end

    # Determine whether a native build of the given c extension is available
    # for the Ruby ABI version used by the running SketchUp.
    # @param [String] filename C extension filename.
    # @return [Boolean]
    # @since 3.8.0
    def c_extension_available?(filename)
      available_c_extension_abis(filename).include?(ruby_abi_version)
    end

    # Normalize the given filename by stripping the path and the file
    # extension.
    # @param [String] filename
    # @return [String]
    # @since 3.8.0
    def normalize_filename(filename)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      ::File.basename(filename).gsub(/\.(so|bundle|dll|dylib|rb|rbs|rbe)$/i, '')
    end

    # Add a Ruby file that will be required and ignored from cleanup.
    # @param [String] filename Ruby filename.
    # @note All added rubies are loaded last in the order they are added.
    def add_ruby(filename, only_register = false)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      filename = File.basename(filename).gsub(/\.(rb|rbs|rbe)$/, '')
      @rubies << filename
    end

    # Add a Ruby file that will be ignored from cleanup but not required
    # (loaded).
    # @param [String] filename Ruby filename.
    def add_ruby_no_require(filename)
      filename = filename.to_s.dup
      filename.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      filename = File.basename(filename).gsub(/\.(rb|rbs|rbe)$/, '')
      @rubies_no_require << filename
    end

    # Copy and load all the required and optional files.
    # @note All .dll files are loaded first, in the order they are added, all
    #   .so or .bundle files afterwards, and all ruby files last. All .dylib
    #   files are expected to be loaded by a C extension.
    # @raise [IOError, LoadError] if a required file doesn't exist.
    # @return [void]
    def require_all
      ops = AMS::IS_PLATFORM_WINDOWS ? 'win' : 'osx'
      bit = AMS::IS_SKETCHUP_64BIT ? '64' : '32'
      rbv = RUBY_VERSION[0..2].to_s
      c_ext = AMS::IS_PLATFORM_WINDOWS ? '.so' : '.bundle'
      l_ext = AMS::IS_PLATFORM_WINDOWS ? '.dll' : '.dylib'

      stage_path = ::File.join(@ext_path, 'libraries', 'stage')
      stage_lib_path = ::File.join(stage_path, ops + bit)
      stage_ext_path = ::File.join(stage_lib_path, rbv)

      # Libraries, such as newton.dll, can be overridden per Ruby ABI version by
      # placing them in <i>libraries/stage/PLATFORM + BIT/RUBY_VERSION/</i>.
      # This allows shipping libraries that are compatible with only certain
      # Ruby versions, e.g. different builds of one and the same library
      # compiled against different C runtime libraries.
      lib_stage_source = lambda { |fname|
        abi_fpath = ::File.join(stage_lib_path, rbv, fname)
        ::File.exist?(abi_fpath) ? abi_fpath : ::File.join(stage_lib_path, fname)
      }

      version_path = ::File.join(@ext_path, 'libraries', @ext_version)
      version_lib_path = ::File.join(version_path, ops + bit)
      version_ext_path = ::File.join(version_lib_path, rbv)

      temp_version_path = ::File.join(AMS.get_temp_dir, @ext_name, 'libraries', @ext_version)
      temp_version_lib_path = ::File.join(temp_version_path, ops + bit)
      temp_version_ext_path = ::File.join(temp_version_lib_path, rbv)

      load_path_id = 0 # 0 - stage_path, 1 - version_path, 2 - temp_version_path

      # Check if all the required files exist at version_path
      libraries_exist = true
      @libraries.each { |data|
        next unless data[1]
        fpath = ::File.join(version_lib_path, data[0] + l_ext)
        unless ::File.exist?(fpath)
          libraries_exist = false
          break
        end
      }
      if libraries_exist
        @c_extensions.each { |filename|
          fpath = ::File.join(version_ext_path, filename + c_ext)
          unless ::File.exist?(fpath)
            libraries_exist = false
            break
          end
        }
      end
      load_path_id = 1 if libraries_exist
      # If not, check if all the required files exist at temp_version_path
      unless libraries_exist
        libraries_exist = true
        @libraries.each { |data|
          next unless data[1]
          fpath = ::File.join(temp_version_lib_path, data[0] + l_ext)
          unless ::File.exist?(fpath)
            libraries_exist = false
            break
          end
        }
        if libraries_exist
          @c_extensions.each { |filename|
            fpath = ::File.join(temp_version_ext_path, filename + c_ext)
            unless ::File.exist?(fpath)
              libraries_exist = false
              break
            end
          }
        end
        load_path_id = 2 if libraries_exist
      end
      # If not or experimental mode is turned on
      if !libraries_exist || @experimental
        # First verify that all the required stage files exist
        unless ::File.directory?(stage_path)
          raise(IOError, "Stage directory, \"#{stage_path}\", is missing!")
        end
        @libraries.each { |data|
          next unless data[1]
          fpath = lib_stage_source.call(data[0] + l_ext)
          unless ::File.exist?(fpath)
            raise(IOError, "The required, staged library file, \"#{fpath}\", is missing!")
          end
        }
        @c_extensions.each { |filename|
          fpath = ::File.join(stage_ext_path, filename + c_ext)
          unless ::File.exist?(fpath)
            raise(IOError, "The required, staged c extension file, \"#{fpath}\", is missing!")
          end
        }
        # Create directory to version_ext_path
        copying_success = true
        unless ::File.directory?(version_ext_path)
          begin
            FileUtils.mkdir_p(version_ext_path)
          rescue Exception => err
            copying_success = false
          end
        end
        # If the directory to version_ext_path was successfully created
        if copying_success
          # Attempt to copy all the library stage files to version_lib_path
          @libraries.each { |data|
            fname = data[0] + l_ext
            src_path = lib_stage_source.call(fname)
            dst_path = ::File.join(version_lib_path, fname)
            # Skip if the file is already copied; or overwrite with a newer version.
            #~ next if ::File.exist?(dst_path)
            # Skip if the file is optional and doesn't exist at stage.
            # If the file is required and doesn't exist at stage,
            # the IOError is raised in code above.
            next if !data[1] && !::File.exist?(src_path)
            # Otherwise copy from stage_lib_path to version_lib_path.
            begin
              FileUtils.copy_file(src_path, dst_path)
            rescue Exception => err
              copying_success = false
              break
            end
          }
        end
        # If the required libraries were successfully copied to version_lib_path
        if copying_success
          # Attempt to copy all the c extension stage files to version_ext_path
          @c_extensions.each { |filename|
            fname = filename + c_ext
            src_path = ::File.join(stage_ext_path, fname)
            dst_path = ::File.join(version_ext_path, fname)
            # Copy from stage_ext_path to version_ext_path.
            begin
              FileUtils.copy_file(src_path, dst_path)
            rescue Exception => err
              copying_success = false
              break
            end
          }
        end
        # If all libraries and c extension files were copied successfully to version_path
        if copying_success
          # Set load path to version_path
          load_path_id = 1
        else
          # Create directory to temp_version_ext_path
          copying_success = true
          unless ::File.directory?(temp_version_ext_path)
            begin
              FileUtils.mkdir_p(temp_version_ext_path)
            rescue Exception => err
              copying_success = false
            end
          end
          if copying_success
            # Attempt to copy all the library stage files to the temp_version_lib_path.
            @libraries.each { |data|
              fname = data[0] + l_ext
              src_path = lib_stage_source.call(fname)
              dst_path = ::File.join(temp_version_lib_path, fname)
              # Skip if the file is already copied; or overwrite with a newer version.
              #~ next if ::File.exist?(dst_path)
              # Skip if the file is optional and doesn't exist at stage.
              # If the file is required and doesn't exist at stage,
              # the IOError is raised in code above.
              next if !data[1] && !::File.exist?(src_path)
              # Copy from stage_lib_path to temp_version_lib_path
              begin
                FileUtils.copy_file(src_path, dst_path)
              rescue Exception => err
                copying_success = false
                break
              end
            }
          end
          # If the required libraries were successfully copied to version_lib_path
          if copying_success
            # Attempt to copy all the c extension stage files to version_ext_path
            @c_extensions.each { |filename|
              fname = filename + c_ext
              src_path = ::File.join(stage_ext_path, fname)
              dst_path = ::File.join(temp_version_ext_path, fname)
              # Copy from stage_ext_path to temp_version_ext_path
              begin
                FileUtils.copy_file(src_path, dst_path)
              rescue Exception => err
                copying_success = false
                break
              end
            }
          end
          # If all successfully copied
          if copying_success
            # Set load_path_id to temp_version_path
            load_path_id = 2
          else
            # Otherwise, set load_path_id to stage_path as the last resort
            load_path_id = 0
          end
        end
      end
      # Convert load_path_id to the right paths
      if load_path_id == 0
        lib_load_path = stage_lib_path
        ext_load_path = stage_ext_path
      elsif load_path_id == 1
        lib_load_path = version_lib_path
        ext_load_path = version_ext_path
      else
        lib_load_path = temp_version_lib_path
        ext_load_path = temp_version_ext_path
      end
      # Load all libraries in given order
      #
      # On Windows the libraries the c extension links against have to be
      # loaded into the process before the c extension itself is required, as
      # Windows does not look for the dependencies of a library in the folder
      # of that library.
      dll_report = nil
      if !@libraries.empty? && AMS::IS_PLATFORM_WINDOWS
        dll_report = "Libraries:\n"
        failed = []
        reports_status = AMS::DLL.respond_to?(:load_library_info)
        @libraries.each { |data|
          fname = data[0] + l_ext
          fpath = ::File.join(lib_load_path, fname)
          fpath.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
          if !::File.exist?(fpath)
            dll_report << sprintf("%s : missing%s\n", fname, data[1] ? ' (required)' : '')
            failed << [fname, data[1], 'The file does not exist.'] if data[1]
          elsif reports_status
            status, detail = AMS::DLL.load_library_info(fpath)
            attempts = AMS::DLL.respond_to?(:library_attempts) ? AMS::DLL.library_attempts(fpath) : []
            case status
            when :loaded
              dll_report << sprintf("%s : loaded (handle %d)\n", fname, detail.to_i)
            when :unverified
              dll_report << sprintf("%s : loaded, but the handle could not be verified (%s)\n", fname, detail)
            else
              dll_report << sprintf("%s : FAILED%s\n", fname, data[1] ? '' : ' (optional)')
              attempts.each { |attempt| dll_report << "    #{attempt}\n" }
              failed << [fname, data[1], detail, attempts] if data[1]
            end
          else
            # An older AMS Library provides no detailed result.
            handle = AMS::DLL.load_library(fpath)
            if handle.to_i > 0
              dll_report << sprintf("%s : loaded (handle %d)\n", fname, handle.to_i)
            else
              dll_report << sprintf("%s : FAILED\n", fname)
              failed << [fname, data[1], 'The library could not be loaded.'] if data[1]
            end
          end
        }
        # Report the required libraries that could not be loaded right away:
        # the c extension of the extension will fail to load with an error that
        # is much harder to diagnose, e.g. "The specified module could not be
        # found", which does not name the library that is missing.
        unless failed.empty?
          names = failed.map { |name, _required, _detail, _attempts| name }
          msg = "The required #{names.size == 1 ? 'library' : 'libraries'} of " \
                "#{@ext_name} could not be loaded into SketchUp! " \
                "The engine of the extension cannot work without #{names.size == 1 ? 'it' : 'them'}.\n"
          failed.each { |name, _required, _detail, attempts|
            msg << "  - #{name}:\n"
            attempts.each { |attempt| msg << "      #{attempt}\n" }
          }
          msg << "\n#{dll_report}"
          if AMS::DLL.respond_to?(:describe_dependencies)
            # The reason why a library cannot be loaded is often a library that
            # library depends on, so report what the libraries need.
            first_path = ::File.join(lib_load_path, failed.first[0])
            report = AMS::DLL.describe_dependencies(first_path, [lib_load_path])
            msg << "\n#{report}" unless report.to_s.empty?
          end
          raise(IOError, msg)
        end
      end
      # Load all c extensions in given order
      @c_extensions.each { |filename|
        fname = filename + c_ext
        fpath = ::File.join(ext_load_path, fname)
        if ::File.exist?(fpath)
          cookie = nil
          begin
            # On Windows, the libraries the c extension links against have to
            # be loadable at this point; Windows does not look for them in the
            # folder of the c extension. Loading each library into the process
            # beforehand (see above) is the reliable way to do this. As a
            # safety net, the folder that holds the libraries is also made a
            # part of the search path of the libraries of this process for the
            # duration of the require.
            if AMS::IS_PLATFORM_WINDOWS && defined?(AMS::FallbackHelper) &&
               AMS::FallbackHelper.respond_to?(:add_dll_directory)
              cookie = AMS::FallbackHelper.add_dll_directory(lib_load_path)
            end
            if AMS::IS_PLATFORM_WINDOWS && cookie.nil? && dll_report && ::File.directory?(lib_load_path)
              # Windows looks for the libraries of a library in the working
              # directory as well, unless the process restricts the search.
              ::Dir.chdir(lib_load_path) { ::Kernel.require(fpath) }
            else
              ::Kernel.require(fpath)
            end
          rescue LoadError => e
            msg = "An exception occurred while loading #{@ext_name}, version #{@ext_version}!\n\n#{e.message}"
            msg << "\n\n#{dll_report}" if dll_report
            if AMS::DLL.respond_to?(:ruby_library_mismatch)
              mismatch = AMS::DLL.ruby_library_mismatch(fpath)
              msg << "\n\n#{mismatch}" unless mismatch.nil?
            end
            if AMS::DLL.respond_to?(:describe_dependencies)
              report = AMS::DLL.describe_dependencies(fpath, [lib_load_path, ext_load_path])
              msg << "\n\n#{report}" unless report.to_s.empty?
            end
            raise(e.class, msg, caller)
          ensure
            if cookie && defined?(AMS::FallbackHelper) &&
               AMS::FallbackHelper.respond_to?(:remove_dll_directory)
              AMS::FallbackHelper.remove_dll_directory(cookie)
            end
          end
        else
          abis = available_c_extension_abis(filename)
          msg = "The c extension, \"#{filename}#{c_ext}\", is missing for Ruby #{rbv} on #{ops}#{bit}!"
          msg << " Native builds are available for Ruby: #{abis.join(', ')}." unless abis.empty?
          msg << " Expected file: #{fpath}"
          msg << " The extension has to be rebuilt for Ruby #{rbv}, or a pure-Ruby" \
                 " fallback implementation has to be used instead."
          raise(IOError, msg)
        end
      }
      # Require all the rubies in given order
      @rubies.each { |filename|
        fpath = ::File.join(@ext_path, filename)
        ::Sketchup.require(fpath)
      }
    end

    # Erase all unused libraries, c extension files, and unregistered ruby files
    # (if <tt>clean_rubies</tt> is enabled).
    # @note This does not erase any files from the TEMP folder, as they may be
    #   used by other SketchUp versions.
    # @note This does not raise any errors upon failure to delete a file or a
    #   directory.
    # @param [Boolean] clean_rubies Whether to delete all unregistered Ruby
    #   files within <i>EXT_PATH</i>.
    # @return [void]
    def clean_up(clean_rubies = false)
      lib_load_dir = ::File.join(@ext_path, 'libraries')
      lib_load_dir.force_encoding("UTF-8") unless AMS::IS_RUBY_VERSION_18
      if ::File.directory?(lib_load_dir)
        to_skip = ['.', '..', 'stage', @ext_version]
        ::Dir.entries(lib_load_dir).each { |entry|
          next if to_skip.include?(entry)
          entry_fpath = ::File.join(lib_load_dir, entry)
          entry_fpath.force_encoding("UTF-8") unless AMS::IS_RUBY_VERSION_18
          begin
            FileUtils.rm_r(entry_fpath)
          rescue Exception => err
            # Do nothing
          end
        }
      end
      if clean_rubies
        ::Dir.glob( ::File.join(@ext_path, '*.{rb, rbs, rbe}') ).each { |fpath|
          fpath.force_encoding("UTF-8") unless AMS::IS_RUBY_VERSION_18
          basename = ::File.basename(fpath, '.*')
          next if @rubies.include?(basename) || @rubies_no_require.include?(basename)
          begin
            ::File.delete(fpath)
          rescue Exception => err
            # Do nothing
          end
        }
      end
    end

  end # class ExtensionManager
end # module AMS
