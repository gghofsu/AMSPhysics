cfpath = __FILE__.dup
cfpath.force_encoding('UTF-8') if cfpath.respond_to?(:force_encoding)

plugin_file = File.expand_path('../../ams_Lib', cfpath)
# Some installations use a lower case folder name. This matters on case
# sensitive file systems.
plugin_file = File.expand_path('../../ams_lib', cfpath) unless File.exist?(plugin_file + '.rb')
begin
  Sketchup.require plugin_file
rescue Exception => err
  # The AMS Library installed next to this extension could not be loaded, e.g.
  # because it is outdated and does not support the Ruby version used by the
  # running SketchUp. Continue with the copy bundled with this extension, which
  # is loaded right after this block.
  msg = "[AMS Library] Could not load #{plugin_file}: #{err.class}: #{err.message}"
  puts msg
end

# AMS is a top level namespace of AMS Library.
# @since 1.0.0
module AMS

  # @since 2.0.0
  IS_PLATFORM_WINDOWS = (RUBY_PLATFORM =~ /mswin|mingw/i ? true : false)

  # @since 2.0.0
  IS_PLATFORM_OSX = (RUBY_PLATFORM =~ /darwin/i ? true : false)

  # @since 2.0.0
  IS_PLATFORM_LINUX = (RUBY_PLATFORM =~ /linux/i ? true : false)

  # @since 3.5.0
  IS_RUBY_VERSION_18 = (RUBY_VERSION =~ /^1.8/ ? true : false)

  # @since 3.5.0
  IS_RUBY_VERSION_20 = (RUBY_VERSION =~ /^2.0/ ? true : false)

  # @since 3.5.0
  IS_RUBY_VERSION_22 = (RUBY_VERSION =~ /^2.2/ ? true : false)

  # @since 3.6.0
  IS_RUBY_VERSION_25 = (RUBY_VERSION =~ /^2.5/ ? true : false)

  # @since 3.7.0
  IS_RUBY_VERSION_27 = (RUBY_VERSION =~ /^2.7/ ? true : false)

  # @since 3.8.0
  IS_RUBY_VERSION_30 = (RUBY_VERSION =~ /^3.0/ ? true : false)

  # @since 3.8.0
  IS_RUBY_VERSION_31 = (RUBY_VERSION =~ /^3.1/ ? true : false)

  # @since 3.8.0
  IS_RUBY_VERSION_32 = (RUBY_VERSION =~ /^3.2/ ? true : false)

  # @since 3.8.0
  IS_RUBY_VERSION_33 = (RUBY_VERSION =~ /^3.3/ ? true : false)

  # @since 3.8.0
  IS_RUBY_VERSION_34 = (RUBY_VERSION =~ /^3.4/ ? true : false)

  # Ruby ABI version used by the running SketchUp, e.g. "3.2".
  # @since 3.8.0
  RUBY_ABI_VERSION = RUBY_VERSION[0..2].to_s.freeze

  # @since 3.5.0
  IS_SKETCHUP_64BIT = ((::Sketchup.respond_to?('is_64bit?') && ::Sketchup.is_64bit?) ? true : false)

  # @since 3.5.0
  IS_SKETCHUP_32BIT = !IS_SKETCHUP_64BIT

  # @since 3.6.0
  SU_MAJOR_VERSION = ::Sketchup.version.to_i

  class << self

    # Clamp value between minimum and maximum limits.
    # @param [Numeric] val
    # @param [Numeric, nil] min_val Pass `nil` to have no min limit.
    # @param [Numeric, nil] max_val Pass `nil` to have no max limit.
    # @return [Numeric]
    # @since 2.0.0
    def clamp(val, min_val, max_val)
      if (min_val && val < min_val)
        min_val
      elsif (max_val && val > max_val)
        max_val
      else
        val
      end
    end

    # Get the minimum of two values
    # @param [Numeric] a
    # @param [Numeric] b
    # @return [Numeric]
    # @since 2.0.0
    def min(a, b)
      (a < b) ? a : b
    end

    # Get the maximum of two values
    # @param [Numeric] a
    # @param [Numeric] b
    # @return [Numeric]
    # @since 2.0.0
    def max(a, b)
      (a > b) ? a : b
    end

    # Get sign of a numeric value.
    # @param [Numeric] val
    # @return [Integer] -1, 0, or 1
    # @since 2.0.0
    def sign(val)
      if val > 0
        return 1
      elsif val < 0
        return -1
      else
        return 0
      end
    end

    if AMS::IS_PLATFORM_WINDOWS

      # @return [String]
      # @since 3.7.0
      def get_temp_dir
        appdata = ::AMS.respond_to?('get_folder_path') && ::AMS.get_folder_path(0x001c | 0x8000)
        if appdata
          dir = ::File.join(::File.expand_path(appdata), 'Temp')
        else
          if ENV['LOCALAPPDATA']
            dir = ::File.join(::File.expand_path(ENV['LOCALAPPDATA']), 'Temp')
          else
            base = ENV['TEMP'] || ENV['TMP'] || ENV['TMPDIR']
            dir = base ? ::File.expand_path(base) : ::File.expand_path('.')
          end
        end
        dir.force_encoding('UTF-8') unless IS_RUBY_VERSION_18
        return dir
      end

      # @since 3.6.0
      def refresh_toolbars
      end

    else

      def get_temp_dir
        dir = ENV['TMPDIR'] || ENV['TMP'] || ENV['TEMP']
        if dir.nil? || dir.empty?
          begin
            dir = ::Dir.tmpdir
          rescue Exception
            dir = nil
          end
        end
        dir = '.' if dir.nil? || dir.empty?
        dir = ::File.expand_path(dir)
        dir.force_encoding('UTF-8') unless IS_RUBY_VERSION_18
        return dir
      end

      if AMS::SU_MAJOR_VERSION >= 18

        def refresh_toolbars
          ::UI.refresh_toolbars
        end

      else

        def refresh_toolbars
          model = ::Sketchup.active_model
          return unless model
          model.tools.push_tool(nil)
          model.tools.pop_tool
        end

      end
    end

  end # class << self
end # module AMS

unless file_loaded?(cfpath)
  file_loaded(cfpath)

  dir = File.dirname(cfpath)

  Sketchup.require(File.join(dir, 'extension_manager'))

  ext_manager = AMS::ExtensionManager.new(dir, AMS::Lib::VERSION, false)
  # The native part of the library is only available for the Ruby versions it
  # was compiled for. When there is no build for the Ruby version used by the
  # running SketchUp, the pure Ruby fallback implementation is loaded instead,
  # so that extensions that depend on AMS Library keep working.
  native_available = ext_manager.c_extension_available?('ams_lib')
  ext_manager.add_c_extension('ams_lib') if native_available
  #require ::File.expand_path("../../ext-cpp/projects/vs/x64/ams_lib/Debug (#{RUBY_VERSION.to_f})/ams_lib.so", dir)
  #require ::File.expand_path("../../ext-cpp/projects/vs/x64/ams_lib/Release (#{RUBY_VERSION.to_f})/ams_lib.so", dir)
  ext_manager.add_ruby_no_require('main')
  ext_manager.add_ruby_no_require('extension_manager')
  # ruby_fallback.rb is loaded by the code below, but it has to be registered
  # with the extension manager as well: clean_up deletes every Ruby file of the
  # library that is not registered, and it deleted the fallback implementation
  # from the installations of older releases, which left them broken.
  ext_manager.add_ruby_no_require('ruby_fallback')
  ext_manager.add_ruby('translate')
  # Require the C extension, if available. The C extension is required by
  # ExtensionManager#require_all. When it is missing, the Ruby fallback is
  # loaded, which implements the very same API.
  ext_manager.require_all

  # Whether the native part of AMS Library is loaded.
  # @since 3.8.0
  AMS.const_set(:NATIVE_EXTENSION_LOADED, native_available ? true : false) unless AMS.const_defined?(:NATIVE_EXTENSION_LOADED)

  # Whether the pure Ruby fallback is loaded, because no native build of the
  # library exists for the Ruby version used by the running SketchUp.
  # @since 3.8.0
  AMS.const_set(:RUBY_FALLBACK_LOADED, native_available ? false : true) unless AMS.const_defined?(:RUBY_FALLBACK_LOADED)

  unless native_available
    fallback_file = ::File.join(dir, 'ruby_fallback')
    unless ::File.exist?(fallback_file + '.rb')
      raise(LoadError, "The AMS Library folder is incomplete: \"#{fallback_file}.rb\" is " \
        "missing! AMS Library has to be reinstalled, or the file has to be restored.")
    end
    Sketchup.require(fallback_file)
  end

  ext_manager.clean_up(true)
end

#t = UI.start_timer(2, false){ UI.stop_timer(t); AMS::Sketchup.switch_full_screen(true, 2, 2)}
#AMS::Sketchup.show_toolbar_container(1, false, false)
#r = AMS::Window.get_rect(AMS::Sketchup.get_main_window)
#AMS::Window.set_rect(AMS::Sketchup.get_main_window, r[0], r[1], r[2], r[3] + 1, false)
