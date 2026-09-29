require 'MSPhysics.rb'

module MSPhysics

  # @!visibility private
  # Whether the loaded AMS Library can be used with the Ruby version of the
  # running SketchUp.
  #
  # AMS Library 3.8.0 and later load either the native part of the library or,
  # when there is no native build for the running Ruby version, a pure Ruby
  # fallback. Older versions (3.7.1b and before) only work with Ruby 2.x, as
  # they rely on methods that were removed in Ruby 3, e.g. File.exists?.
  # @return [Boolean]
  # @since 1.1.2
  def self.ams_library_usable?
    return false unless defined?(::AMS::Lib)
    return false unless ::AMS::Lib.const_defined?(:VERSION, false)
    return true if ::AMS.const_defined?(:NATIVE_EXTENSION_LOADED, false)
    return true if ::AMS.const_defined?(:RUBY_FALLBACK_LOADED, false)
    RUBY_VERSION.to_f < 3.0
  end

  # @!visibility private
  # Load the AMS Library. The copy installed next to this extension is
  # preferred; the copy bundled with MSPhysics is used when the installed one
  # cannot be loaded, e.g. because it is outdated and does not support the Ruby
  # version of the running SketchUp.
  # @param [String] ext_dir Path of the MSPhysics extension folder.
  # @return [Array(Boolean, Array<String>)] Whether the library was loaded, and
  #   the problems that were encountered while trying.
  # @since 1.1.2
  def self.load_ams_library(ext_dir)
    problems = []
    plugins_dir = ::File.dirname(ext_dir)
    candidates = [
      ::File.expand_path(::File.join(plugins_dir, 'ams_Lib', 'main')),
      ::File.expand_path(::File.join(plugins_dir, 'ams_lib', 'main'))
    ].select { |candidate| ::File.exist?(candidate + '.rb') }
    # On Windows the two spellings refer to the same folder.
    candidates = RUBY_PLATFORM =~ /mswin|mingw/i ? candidates.uniq { |path| path.downcase } : candidates.uniq
    if candidates.empty?
      return [false, ["AMS Library was not found at #{::File.join(plugins_dir, 'ams_Lib')} or #{::File.join(plugins_dir, 'ams_lib')}"]]
    end
    candidates.each { |candidate|
      begin
        require candidate
      rescue Exception => err
        problems << "#{candidate}.rb: #{err.class}: #{err.message}"
        next
      end
      unless ams_library_usable?
        version = ::AMS::Lib.const_defined?(:VERSION, false) ? ::AMS::Lib::VERSION : '?'
        problems << "#{candidate}.rb: AMS Library #{version} cannot be used with Ruby #{RUBY_VERSION}"
        next
      end
      return [true, problems]
    }
    [false, problems]
  end

  # @!visibility private
  # Collect information about the environment in which the extension is being
  # loaded, so that a failed load can be diagnosed without accessing the
  # machine. SketchUp's own extension error report may hide the actual error.
  # @return [Array<String>]
  # @since 1.1.2
  def self.load_diagnostics
    safe = lambda { |&block|
      begin
        block.call.to_s
      rescue Exception => err
        "#{err.class}: #{err.message}"
      end
    }
    lines = []
    lines << 'Environment:'
    lines << "  MSPhysics: #{defined?(VERSION) ? VERSION : '?'} (#{RUBY_VERSION}, #{RUBY_PLATFORM})"
    lines << "  SketchUp: #{safe.call { ::Sketchup.version }} (Ruby API #{safe.call { ::Sketchup.respond_to?(:version_number) ? ::Sketchup.version_number : '?' }}, 64bit: #{safe.call { ::Sketchup.is_64bit? }})"
    lines << "  Extension folder: #{safe.call { ::File.dirname(__FILE__) }}"
    lines << "  Ruby load path: #{safe.call { $LOAD_PATH.grep(/Plugins|tools/i).inspect }}"
    if defined?(::AMS)
      lines << "  AMS Library: #{safe.call { ::AMS::Lib::VERSION }}"
      lines << "  AMS Library loaded from: #{safe.call { $LOADED_FEATURES.grep(%r{ams_?[Ll]ib/main\.rb\z}).first || 'unknown' }}"
      lines << "  AMS native extension loaded: #{safe.call { ::AMS::NATIVE_EXTENSION_LOADED }}" if ::AMS.const_defined?(:NATIVE_EXTENSION_LOADED, false)
      lines << "  AMS Ruby fallback loaded: #{safe.call { ::AMS::RUBY_FALLBACK_LOADED }}" if ::AMS.const_defined?(:RUBY_FALLBACK_LOADED, false)
      if defined?(::AMS::FallbackHelper)
        lines << "  Fiddle available: #{safe.call { ::AMS::FallbackHelper::FIDDLE_AVAILABLE }}"
        lines << "  Windows API (Fiddle) usable: #{safe.call { ::AMS::FallbackHelper::WIN32_AVAILABLE }}"
      end
    else
      lines << '  AMS Library: not loaded'
    end
    stage_dir = ::File.expand_path(::File.join(::File.dirname(__FILE__), 'libraries', 'stage', (defined?(::AMS::IS_PLATFORM_WINDOWS) && ::AMS::IS_PLATFORM_WINDOWS ? 'win64' : 'osx64')))
    lines << "  Native engines in #{stage_dir}: #{safe.call {
      ::File.directory?(stage_dir) ? ::Dir.entries(stage_dir).select { |entry| ::File.directory?(::File.join(stage_dir, entry)) && entry =~ /\A\d+\.\d+\z/ }.sort.inspect : 'folder does not exist'
    }}"
    # The engine has to be built against the very Ruby library of the running
    # SketchUp, and the name of that library encodes the build of Ruby used.
    if defined?(::AMS::DLL) && ::AMS::DLL.respond_to?(:ruby_library_name)
      lines << "  Ruby library of this SketchUp: #{safe.call { ::AMS::DLL.ruby_library_name }}"
      engine = safe.call {
        abi = RUBY_VERSION[0..2].to_s
        ext = defined?(::AMS::IS_PLATFORM_WINDOWS) && ::AMS::IS_PLATFORM_WINDOWS ? '.so' : '.bundle'
        path = ::File.join(stage_dir, abi, 'msp_lib' + ext)
        ::File.exist?(path) ? path : nil
      }
      lines << "  Engine: #{engine}"
      if engine.to_s.start_with?('/') || engine.to_s =~ /:\A-Za-z:/
        lines << "  Engine is built against: #{safe.call { ::AMS::DLL.imported_ruby_libraries(engine).inspect }}"
        mismatch = safe.call { ::AMS::DLL.ruby_library_mismatch(engine) }
        lines << "  PROBLEM: #{mismatch}" unless mismatch.to_s == 'nil'
      end
    end
    lines
  end

  # @!visibility private
  # Report an error that prevented MSPhysics from loading.
  #
  # SketchUp's own extension error report can hide the actual error, so the
  # error is printed to the Ruby console, written to a text file, and shown to
  # the user.
  # @param [Exception] err
  # @param [String] title
  # @return [String] the full report
  # @since 1.1.2
  def self.report_load_error(err, title = 'MSPhysics failed to load')
    lines = []
    lines << "#{title}!"
    lines << ''
    lines << 'Error:'
    lines << "  #{err.class}: #{err.message}"
    lines << "  #{err.backtrace.first(12).join("\n  ")}" if err.backtrace
    cause = err.cause
    while cause
      lines << ''
      lines << "Caused by #{cause.class}: #{cause.message}"
      lines << "  #{cause.backtrace.first(12).join("\n  ")}" if cause.backtrace
      cause = cause.cause
    end
    lines << ''
    lines.concat(load_diagnostics)
    report = lines.join("\n")

    # Print the report to the Ruby console.
    puts "[MSPhysics] #{report}"

    # Save the report to a file next to the extension, falling back to the
    # temporary folder when the extension folder is not writable.
    path = nil
    [
      ::File.expand_path(::File.join(::File.dirname(__FILE__), 'load_error.txt')),
      begin
        ::File.expand_path(::File.join(defined?(::AMS) && ::AMS.respond_to?(:get_temp_dir) ? ::AMS.get_temp_dir : ::Dir.tmpdir, 'MSPhysics_load_error.txt'))
      rescue Exception
        nil
      end
    ].each { |candidate|
      next unless candidate
      begin
        ::File.open(candidate, 'wb') { |file| file.write(report) }
        path = candidate
        break
      rescue Exception
        nil
      end
    }
    lines << '' << "The full report was saved to: #{path}" if path

    # Show the most important part of the report to the user.
    message = [
      title + '!',
      '',
      "#{err.class}: #{err.message}"
    ]
    cause = err.cause
    while cause
      message << "caused by #{cause.class}: #{cause.message}"
      cause = cause.cause
    end
    message << ''
    message << 'The full report was printed to the Ruby console'
    message << (path ? "and saved to:\n#{path}" : 'and could not be saved to a file.')
    ::UI.messagebox(message.join("\n"))
    report
  end

end # module MSPhysics

# The whole loading process is guarded: when something goes wrong, the error is
# reported here instead of being left to SketchUp's extension loader, which -
# depending on the SketchUp version - replaces it with a less helpful error.
begin
  ext_dir = File.expand_path(File.dirname(__FILE__))

  # Load and verify AMS Library.
  ams_library_loaded, ams_problems = MSPhysics.load_ams_library(ext_dir)

  if ams_library_loaded
    # Verify that there is a native build of the MSPhysics engine for the Ruby
    # version used by the running SketchUp.
    ops = AMS::IS_PLATFORM_WINDOWS ? 'win' : 'osx'
    bit = AMS::IS_SKETCHUP_64BIT ? '64' : '32'
    c_ext = AMS::IS_PLATFORM_WINDOWS ? '.so' : '.bundle'
    stage_dir = File.join(ext_dir, 'libraries', 'stage', ops + bit)
    abi = RUBY_VERSION[0..2].to_s
    available_abis = File.directory?(stage_dir) ? Dir.entries(stage_dir).select { |entry|
      File.exist?(File.join(stage_dir, entry, 'msp_lib' + c_ext))
    }.sort : []
    if available_abis.include?(abi)
      require File.join(ext_dir, 'main')
    else
      msg = "MSPhysics does not have a native engine (msp_lib#{c_ext}) for Ruby #{abi}, which is the Ruby version used by this SketchUp!\n\n"
      if available_abis.empty?
        msg << "No native engine builds were found at all. Please reinstall MSPhysics."
      else
        msg << "This build of MSPhysics supports Ruby: #{available_abis.join(', ')}."
      end
      if AMS::IS_PLATFORM_OSX && RUBY_PLATFORM =~ /arm64/
        msg << "\n\nApple Silicon builds of MSPhysics are not available yet. SketchUp can be " \
               "started with Rosetta, in which case MSPhysics runs with the Intel (x86_64) build."
      end
      msg << "\n\nMSPhysics cannot be loaded without its native engine."
      ::UI.messagebox(msg)
      puts "[MSPhysics] #{msg}"
    end
  else
    msg = "MSPhysics requires AMS Library, version 3.5.0 or later! MSPhysics will not be " \
          "loaded with the library not installed or outdated.\n\n"
    if ams_problems.empty?
      msg << "AMS Library was not found next to the MSPhysics extension folder."
    else
      msg << "What was tried:\n" << ams_problems.map { |problem| "  - #{problem}" }.join("\n")
      msg << "\n\nAMS Library 3.8.0 or later is required for the Ruby version used by this " \
             "SketchUp. Reinstall MSPhysics (which includes AMS Library) or update AMS Library."
    end
    msg << "\n\nWould you like to navigate to the library's download page?"
    puts "[MSPhysics] #{msg}"
    if ::UI.messagebox(msg, MB_YESNO) == IDYES
      ::UI.openURL('http://sketchucation.com/forums/viewtopic.php?f=323&t=55067#p499835')
    end
  end
rescue Exception => err
  MSPhysics.report_load_error(err)
end
