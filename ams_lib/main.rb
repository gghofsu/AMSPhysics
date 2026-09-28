cfpath = __FILE__.dup
cfpath.force_encoding('UTF-8') if cfpath.respond_to?(:force_encoding)

plugin_file = File.expand_path('../../ams_Lib', cfpath)
Sketchup.require plugin_file

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
            dir = ::File.expand_path(ENV['TEMP'])
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
        dir = ::File.expand_path(ENV['TMPDIR'])
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
  ext_manager.add_c_extension('ams_lib')
  #require ::File.expand_path("../../ext-cpp/projects/vs/x64/ams_lib/Debug (#{RUBY_VERSION.to_f})/ams_lib.so", dir)
  #require ::File.expand_path("../../ext-cpp/projects/vs/x64/ams_lib/Release (#{RUBY_VERSION.to_f})/ams_lib.so", dir)
  ext_manager.add_ruby_no_require('main')
  ext_manager.add_ruby_no_require('extension_manager')
  ext_manager.add_ruby('translate')
  ext_manager.require_all
  ext_manager.clean_up(true)
end

#t = UI.start_timer(2, false){ UI.stop_timer(t); AMS::Sketchup.switch_full_screen(true, 2, 2)}
#AMS::Sketchup.show_toolbar_container(1, false, false)
#r = AMS::Window.get_rect(AMS::Sketchup.get_main_window)
#AMS::Window.set_rect(AMS::Sketchup.get_main_window, r[0], r[1], r[2], r[3] + 1, false)
