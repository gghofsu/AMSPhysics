# encoding: UTF-8
#
# Pure Ruby fallback implementation of the AMS Library API.
#
# AMS Library consists of two parts:
#   1. A Ruby part, which is always loaded. (See main.rb and translate.rb.)
#   2. A native part (a C extension), which is only available for the Ruby
#      versions the library was built for.
#
# Whenever SketchUp upgrades its Ruby version, the native part has to be
# rebuilt. When no build exists for the Ruby version used by the running
# SketchUp, the library would previously refuse to load, taking down any
# extension that depends on it. This file implements the subset of the native
# API in pure Ruby so that dependent extensions, such as MSPhysics, can still
# be used.
#
# Notes on the fallback implementation:
#   * Keyboard, cursor, and window functions use the Windows API via Fiddle.
#     They silently degrade into no-ops on non-Windows platforms.
#   * Functions that manage SketchUp's Qt based frame - switching fullscreen,
#     showing/hiding trays and menu bars, embedding dialogs into the frame,
#     and subclassing SketchUp's main window - cannot be replicated in pure
#     Ruby. They are provided as no-ops that return +false+/+nil+, which the
#     dependent code already treats as "feature not available".
#   * Geometry and entity helpers are fully implemented, as they only rely on
#     the SketchUp Ruby API.
#
# @since 3.8.0
module AMS

  # Whether the pure Ruby fallback for the native part of AMS Library is in
  # use.
  # @since 3.8.0
  RUBY_FALLBACK_LOADED = true unless defined?(RUBY_FALLBACK_LOADED)

  # Helper functions of the pure Ruby fallback implementation.
  # @since 3.8.0
  module FallbackHelper

    # Whether Fiddle is available, which is needed to call into the Windows
    # API.
    # @since 3.8.0
    FIDDLE_AVAILABLE = begin
      require 'fiddle'
      require 'fiddle/import'
      true
    rescue LoadError
      false
    end

    # Whether Windows API calls are available.
    # @since 3.8.0
    WIN32_AVAILABLE = FIDDLE_AVAILABLE && AMS::IS_PLATFORM_WINDOWS

    @win32_functions = {}

    class << self

      # Get a function of a Windows library, or +nil+ if it cannot be
      # retrieved.
      # @param [String] library Library name, e.g. 'kernel32'.
      # @param [String] function Function name, e.g. 'LoadLibraryW'.
      # @param [Array<Fixnum>] args Fiddle argument types.
      # @param [Fixnum] ret Fiddle return type.
      # @return [Fiddle::Function, nil]
      # @since 3.8.0
      def win32_function(library, function, args, ret)
        return nil unless WIN32_AVAILABLE
        key = library + '!' + function
        return @win32_functions[key] if @win32_functions.key?(key)
        begin
          handle = Fiddle.dlopen(library)
          fptr = handle[function]
          return nil if fptr.nil?
          @win32_functions[key] = Fiddle::Function.new(fptr, args, ret)
        rescue StandardError, Fiddle::DLError
          nil
        end
      end

      # Convert a Ruby string into a pointer to a null terminated UTF-16
      # string, as expected by the wide character Windows API functions.
      # @param [String] str
      # @return [Fiddle::Pointer, nil]
      # @since 3.8.0
      def wide_string(str)
        return nil unless FIDDLE_AVAILABLE
        Fiddle::Pointer[str.to_s.encode('UTF-16LE') + "\x00".dup.force_encoding('BINARY')]
      rescue StandardError
        nil
      end

      # Call a Windows function, returning +nil+ upon failure.
      # @since 3.8.0
      def call_win32(library, function, args, ret, *values)
        func = win32_function(library, function, args, ret)
        return nil unless func
        func.call(*values)
      rescue StandardError, Fiddle::DLError
        nil
      end

    end # class << self
  end # module FallbackHelper

  unless AMS.respond_to?(:get_folder_path)
    # Get the path of a Windows shell folder. On Windows, this is the native
    # way of resolving special folders, e.g. the local application data
    # folder. When the path cannot be determined, +nil+ is returned, allowing
    # the calling code to fall back to the environment variables.
    # @param [Fixnum] csidl A CSIDL value, e.g. +0x001c+ for the local
    #   application data folder. The +0x8000+ (create) flag is ignored.
    # @return [String, nil] Folder path, or +nil+ when it cannot be
    #   determined.
    # @since 3.8.0
    def self.get_folder_path(csidl)
      return nil unless FallbackHelper::WIN32_AVAILABLE
      size = 520 # MAX_PATH * 2 + 8, in bytes
      buffer = Fiddle::Pointer["\x00".dup.force_encoding('BINARY') * size]
      result = FallbackHelper.call_win32(
        'shell32', 'SHGetFolderPathW',
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_INT,
        0, csidl.to_i & 0xff, 0, 0, buffer
      )
      return nil unless result == 0
      path = buffer[0, size].force_encoding('UTF-16LE').encode('UTF-8').split("\x00").first
      path && !path.empty? ? path.tr('\\', '/') : nil
    rescue StandardError, Fiddle::DLError
      nil
    end
  end

  unless AMS.respond_to?(:validate_type)
    # Validate the type of a value, raising a +TypeError+ when the value is not
    # one of the given types. Returns the value, so that the function can be
    # used inline, e.g. +AMS.validate_type(body, MSPhysics::Body)+.
    # @param [Object] val Value to validate.
    # @param [Array<Class>] types Types the value is allowed to be.
    # @return [Object] The validated value.
    # @raise [TypeError] When the value is not one of the given types.
    # @since 3.8.0
    def self.validate_type(val, *types)
      raise(ArgumentError, 'Expected at least one type to check against.') if types.empty?
      types.each { |type|
        return val if type.is_a?(Module) && val.is_a?(type)
      }
      names = types.map { |type| type.is_a?(Module) ? type.name : type.inspect }
      raise(TypeError, "Invalid parameter! Expected #{names.join(' or ')} but got #{val.class}.")
    end
  end

end # module AMS


# ---------------------------------------------------------------------------
# AMS::DLL
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:DLL, false)
  module AMS
    # Dynamic library management.
    # @since 3.8.0
    module DLL

      TYPE_POINTER = AMS::FallbackHelper::FIDDLE_AVAILABLE ? Fiddle::TYPE_VOIDP : 0

      @loaded = {}

      class << self

        # Load a dynamic library.
        # @param [String] path Path to the library.
        # @return [Fixnum] Handle to the library, or +0+ upon failure.
        # @since 3.8.0
        def load_library(path)
          path = path.to_s
          return 0 unless AMS::FallbackHelper::WIN32_AVAILABLE
          return @loaded[path] if @loaded.key?(path)
          wpath = AMS::FallbackHelper.wide_string(path)
          return 0 unless wpath
          handle = AMS::FallbackHelper.call_win32('kernel32', 'LoadLibraryW',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP, wpath)
          handle = handle.to_i
          handle = 0 if handle < 0
          @loaded[path] = handle
          handle
        end

        # Unload a dynamic library.
        # @param [Fixnum] handle
        # @return [Boolean] success
        # @since 3.8.0
        def free_library(handle)
          return false unless AMS::FallbackHelper::WIN32_AVAILABLE
          return false unless handle.is_a?(Integer) && handle > 0
          result = AMS::FallbackHelper.call_win32('kernel32', 'FreeLibrary',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle)
          return false if result.nil?
          @loaded.delete_if { |_path, h| h == handle }
          result != 0
        end

        # Get a handle to the given module, or +0+ if the module is not
        # loaded.
        # @param [String] name
        # @return [Fixnum]
        # @since 3.8.0
        def get_module_handle(name)
          return 0 unless AMS::FallbackHelper::WIN32_AVAILABLE
          wname = AMS::FallbackHelper.wide_string(name)
          return 0 unless wname
          handle = AMS::FallbackHelper.call_win32('kernel32', 'GetModuleHandleW',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP, wname)
          handle = handle.to_i
          handle < 0 ? 0 : handle
        end

      end # class << self
    end # module DLL
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Keyboard
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Keyboard, false)
  module AMS
    # Access to the keyboard state.
    # @note This fallback implementation polls the key state with the Windows
    #   API, which is equivalent to what the native implementation does.
    # @since 3.8.0
    module Keyboard

      # Virtual key codes of named keys.
      # @since 3.8.0
      KEY_CODES = {
        'backspace' => 0x08, 'tab' => 0x09, 'clear' => 0x0C, 'return' => 0x0D,
        'enter' => 0x0D, 'shift' => 0x10, 'control' => 0x11, 'ctrl' => 0x11,
        'alt' => 0x12, 'menu' => 0x12, 'pause' => 0x13, 'capslock' => 0x14,
        'capital' => 0x14, 'escape' => 0x1B, 'esc' => 0x1B, 'space' => 0x20,
        'pageup' => 0x21, 'prior' => 0x21, 'pagedown' => 0x22, 'next' => 0x22,
        'end' => 0x23, 'home' => 0x24, 'left' => 0x25, 'up' => 0x26,
        'right' => 0x27, 'down' => 0x28, 'select' => 0x29, 'print' => 0x2A,
        'execute' => 0x2B, 'printscreen' => 0x2C, 'snapshot' => 0x2C,
        'insert' => 0x2D, 'delete' => 0x2E, 'del' => 0x2E, 'help' => 0x2F,
        'numlock' => 0x90, 'scrolllock' => 0x91, 'scroll' => 0x91,
        'lshift' => 0xA0, 'rshift' => 0xA1, 'lcontrol' => 0xA2, 'rcontrol' => 0xA3,
        'lalt' => 0xA4, 'ralt' => 0xA5, 'lwin' => 0x5B, 'rwin' => 0x5C,
        'apps' => 0x5D, 'numpad0' => 0x60, 'numpad1' => 0x61, 'numpad2' => 0x62,
        'numpad3' => 0x63, 'numpad4' => 0x64, 'numpad5' => 0x65,
        'numpad6' => 0x66, 'numpad7' => 0x67, 'numpad8' => 0x68,
        'numpad9' => 0x69, 'multiply' => 0x6A, 'add' => 0x6B,
        'separator' => 0x6C, 'subtract' => 0x6D, 'decimal' => 0x6E,
        'divide' => 0x6F, 'num0' => 0x60, 'num1' => 0x61, 'num2' => 0x62,
        'num3' => 0x63, 'num4' => 0x64, 'num5' => 0x65, 'num6' => 0x66,
        'num7' => 0x67, 'num8' => 0x68, 'num9' => 0x69,
        'oem_1' => 0xBA, 'oem_plus' => 0xBB, 'oem_comma' => 0xBC,
        'oem_minus' => 0xBD, 'oem_period' => 0xBE, 'oem_2' => 0xBF,
        'oem_3' => 0xC0, 'oem_4' => 0xDB, 'oem_5' => 0xDC, 'oem_6' => 0xDD,
        'oem_7' => 0xDE,
        'semicolon' => 0xBA, 'equals' => 0xBB, 'comma' => 0xBC,
        'minus' => 0xBD, 'period' => 0xBE, 'slash' => 0xBF,
        'backquote' => 0xC0, 'bracketleft' => 0xDB, 'backslash' => 0xDC,
        'bracketright' => 0xDD, 'quote' => 0xDE
      }.freeze

      class << self

        # Convert a key name, symbol, or character into a virtual key code.
        # @param [String, Symbol, Fixnum] vk
        # @return [Fixnum] Virtual key code, or +0+ if the key is unknown.
        # @since 3.8.0
        def get_key_code(vk)
          return vk.to_i if vk.is_a?(Integer)
          name = vk.to_s.strip
          return 0 if name.empty?
          downcase = name.downcase
          # Letters and digits
          if downcase.size == 1
            char = downcase[0, 1]
            if char =~ /[a-z]/
              return char.upcase.ord
            elsif char =~ /[0-9]/
              return 0x30 + char.to_i
            end
          end
          # Function keys: f1 .. f24
          if downcase =~ /\Af(\d{1,2})\z/
            num = downcase[1..-1].to_i
            return 0x70 + (num - 1) if num >= 1 && num <= 24
          end
          KEY_CODES[downcase] || 0
        end

        # Get the name of a virtual key code, or an empty string when the code
        # is unknown.
        # @param [Fixnum] vkc
        # @return [String]
        # @since 3.8.0
        def get_key_name(vkc)
          vkc = vkc.to_i
          return '0' if vkc == 0x30
          if vkc >= 0x30 && vkc <= 0x39
            return (vkc - 0x30).to_s
          elsif vkc >= 0x41 && vkc <= 0x5A
            return vkc.chr
          elsif vkc >= 0x70 && vkc <= 0x87
            return 'f' + (vkc - 0x70 + 1).to_s
          end
          KEY_CODES.each { |name, code| return name if code == vkc }
          ''
        end

        # Get the state of a key.
        # @param [String, Symbol, Fixnum] vk Virtual key code or name.
        # @return [Fixnum] +1+ if the key is down, +0+ if it is up.
        # @since 3.8.0
        def key(vk)
          key_down?(vk) ? 1 : 0
        end

        # Determine whether a key is down.
        # @param [String, Symbol, Fixnum] vk Virtual key code or name.
        # @return [Boolean]
        # @since 3.8.0
        def key_down?(vk)
          vkc = get_key_code(vk)
          return false if vkc == 0
          state = AMS::FallbackHelper.call_win32('user32', 'GetAsyncKeyState',
            [Fiddle::TYPE_INT], Fiddle::TYPE_SHORT, vkc)
          return false if state.nil?
          (state & 0x8000) != 0
        rescue StandardError
          false
        end
        alias_method(:key_pressed?, :key_down?) rescue nil

        # Determine whether a key is up.
        # @param [String, Symbol, Fixnum] vk Virtual key code or name.
        # @return [Boolean]
        # @since 3.8.0
        def key_up?(vk)
          !key_down?(vk)
        end

        # Determine whether the toggled state of a key is on.
        # @param [String, Symbol, Fixnum] vk Virtual key code or name.
        # @return [Boolean]
        # @since 3.8.0
        def key_toggled?(vk)
          return false if key(vk) == 0
          state = AMS::FallbackHelper.call_win32('user32', 'GetKeyState',
            [Fiddle::TYPE_INT], Fiddle::TYPE_SHORT, get_key_code(vk))
          return false if state.nil?
          (state & 0x0001) != 0
        rescue StandardError
          false
        end

        # @return [Boolean] Whether the Control key is down.
        # @since 3.8.0
        def control_down?
          key_down?('control')
        end

        # @return [Boolean] Whether the Control key is up.
        # @since 3.8.0
        def control_up?
          !control_down?
        end

        # @return [Boolean] Whether the Shift key is down.
        # @since 3.8.0
        def shift_down?
          key_down?('shift')
        end

        # @return [Boolean] Whether the Shift key is up.
        # @since 3.8.0
        def shift_up?
          !shift_down?
        end

        # @return [Boolean] Whether the Alt/Menu key is down.
        # @since 3.8.0
        def alt_down?
          key_down?('alt')
        end

        # @return [Boolean] Whether the Alt/Menu key is up.
        # @since 3.8.0
        def alt_up?
          !alt_down?
        end
        alias_method(:menu_down?, :alt_down?) rescue nil
        alias_method(:menu_up?, :alt_up?) rescue nil

        # @return [Boolean] Whether the Caps Lock key is toggled on.
        # @since 3.8.0
        def capslock_down?
          key_toggled?('capslock')
        end

        # @return [Boolean] Whether the Caps Lock key is toggled off.
        # @since 3.8.0
        def capslock_up?
          !capslock_down?
        end

        # @return [Boolean] Whether the Num Lock key is toggled on.
        # @since 3.8.0
        def numlock_down?
          key_toggled?('numlock')
        end

        # @return [Boolean] Whether the Num Lock key is toggled off.
        # @since 3.8.0
        def numlock_up?
          !numlock_down?
        end

        # @return [Boolean] Whether the Scroll Lock key is toggled on.
        # @since 3.8.0
        def scrolllock_down?
          key_toggled?('scrolllock')
        end

        # @return [Boolean] Whether the Scroll Lock key is toggled off.
        # @since 3.8.0
        def scrolllock_up?
          !scrolllock_down?
        end

        # Key bindings are not supported by the fallback implementation.
        # @return [Boolean] false
        # @since 3.8.0
        def bind(*args)
          false
        end

        # Key bindings are not supported by the fallback implementation.
        # @return [Boolean] false
        # @since 3.8.0
        def unbind(*args)
          false
        end

      end # class << self
    end # module Keyboard
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Cursor
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Cursor, false)
  module AMS
    # Access to the mouse cursor.
    # @since 3.8.0
    module Cursor

      @visible = true

      class << self

        # Show or hide the mouse cursor.
        # @param [Boolean] state
        # @return [Boolean] Whether the visibility of the cursor was changed.
        # @since 3.8.0
        def show(state)
          state = state ? true : false
          return false if state == @visible
          result = AMS::FallbackHelper.call_win32('user32', 'ShowCursor',
            [Fiddle::TYPE_INT], Fiddle::TYPE_INT, state ? 1 : 0)
          return false if result.nil?
          @visible = state
          true
        rescue StandardError
          false
        end

        # Determine whether the mouse cursor is visible.
        # @return [Boolean]
        # @since 3.8.0
        def is_visible?
          @visible
        end

        # Set the position of the mouse cursor.
        # @note Unlike the native implementation, the given coordinates are
        #   interpreted as screen coordinates, as the frame of the SketchUp
        #   window is no longer accessible from Ruby.
        # @param [Fixnum] x
        # @param [Fixnum] y
        # @param [Fixnum] mode
        # @return [Boolean] success
        # @since 3.8.0
        def set_pos(x, y, mode = 0)
          AMS::FallbackHelper.call_win32('user32', 'SetCursorPos',
            [Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_INT,
            x.to_i, y.to_i) ? true : false
        rescue StandardError
          false
        end

        # Not supported by the fallback implementation.
        # @return [nil]
        # @since 3.8.0
        def get_pos
          nil
        end

        # Not supported by the fallback implementation.
        # @return [Boolean] false
        # @since 3.8.0
        def clip(*args)
          false
        end

      end # class << self
    end # module Cursor
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::MIDI
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:MIDI, false)
  module AMS
    # MIDI playback is not supported by the fallback implementation. All of
    # the functions are no-ops, and the dependent code already treats their
    # return values as "no MIDI device available".
    # @since 3.8.0
    module MIDI

      class << self

        # @return [Boolean] false
        # @since 3.8.0
        def open_device(*args)
          false
        end

        # @return [Boolean] false
        # @since 3.8.0
        def close_device(*args)
          false
        end

        # @return [Boolean] false
        # @since 3.8.0
        def is_device_open?(*args)
          false
        end

        # @return [Boolean] false
        # @since 3.8.0
        def reset(*args)
          false
        end

        # @return [nil]
        # @since 3.8.0
        def play_note(*args)
          nil
        end

        # @return [nil]
        # @since 3.8.0
        def stop_note(*args)
          nil
        end

        # @return [nil]
        # @since 3.8.0
        def set_note_position(*args)
          nil
        end

        # @return [nil]
        # @since 3.8.0
        def change_channel_controller(*args)
          nil
        end

      end # class << self
    end # module MIDI
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::System
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:System, false)
  module AMS
    # System information.
    # @since 3.8.0
    module System

      class << self

        # Get the version of the running Windows, e.g. +6.2+ for Windows 8 and
        # above. Returns +0.0+ on non-Windows platforms.
        # @return [Float]
        # @since 3.8.0
        def get_windows_version
          return 0.0 unless AMS::FallbackHelper::WIN32_AVAILABLE
          # OSVERSIONINFOW: 20 bytes of header, followed by a 128 characters
          # wide string.
          buffer = "\x00".dup.force_encoding('BINARY') * 276
          buffer[0, 4] = [276].pack('L<')
          ptr = Fiddle::Pointer[buffer]
          result = AMS::FallbackHelper.call_win32('ntdll', 'RtlGetVersion',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG, ptr)
          return 6.2 if result.nil?
          major, minor = buffer[4, 8].unpack('L<L<')
          major.to_f + minor.to_f / 10.0
        rescue StandardError
          6.2
        end

        # @return [Boolean] Whether the running Windows is 64bit.
        # @since 3.8.0
        def is_windows_64bit?
          AMS::IS_SKETCHUP_64BIT
        end

        # @return [Boolean] false
        # @since 3.8.0
        def is_windows_8_or_higher?
          get_windows_version >= 6.2
        end

      end # class << self
    end # module System
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Window
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Window, false)
  module AMS
    # Window management.
    #
    # @note SketchUp moved to a Qt based frame, and the frame is no longer
    #   accessible as a plain Win32 window from a Ruby extension. Therefore,
    #   the functions that rely on subclassing SketchUp's windows are limited
    #   to plain Win32 calls on the window handles that are explicitly given to
    #   them.
    # @since 3.8.0
    module Window

      class << self

        # @param [Fixnum] handle
        # @return [Boolean] false
        # @since 3.8.0
        def lock_update(*args)
          false
        end

        # Get a window long value.
        # @param [Fixnum, nil] handle
        # @param [Fixnum] index
        # @return [Fixnum, nil]
        # @since 3.8.0
        def get_long(handle, index)
          return nil unless handle.is_a?(Integer) && handle != 0
          AMS::FallbackHelper.call_win32('user32', 'GetWindowLongW',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT,
            handle, index.to_i)
        rescue StandardError
          nil
        end

        # Set a window long value.
        # @param [Fixnum, nil] handle
        # @param [Fixnum] index
        # @param [Fixnum] value
        # @return [Boolean] success
        # @since 3.8.0
        def set_long(handle, index, value)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'SetWindowLongW',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_INT],
            Fiddle::TYPE_INT, handle, index.to_i, value.to_i)
          !result.nil?
        rescue StandardError
          false
        end

        # Get the window rectangle as +[left, top, right, bottom]+.
        # @param [Fixnum, nil] handle
        # @return [Array<Fixnum>, nil]
        # @since 3.8.0
        def get_rect(handle)
          rect_from(handle) { nil }
        end

        # Set the window rectangle.
        # @return [Boolean] false - not supported by the fallback implementation.
        # @since 3.8.0
        def set_rect(*args)
          false
        end

        # Get the client rectangle as +[left, top, right, bottom]+.
        # @param [Fixnum, nil] handle
        # @return [Array<Fixnum>, nil]
        # @since 3.8.0
        def get_client_rect(handle)
          return nil unless handle.is_a?(Integer) && handle != 0
          buffer = [0, 0, 0, 0].pack('l<l<l<l<')
          ptr = Fiddle::Pointer[buffer]
          result = AMS::FallbackHelper.call_win32('user32', 'GetClientRect',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle, ptr)
          return nil if result.nil? || result == 0
          buffer.unpack('l<l<l<l<')
        rescue StandardError
          nil
        end

        # Get the size of a window as an array of +[width, height]+.
        # @param [Fixnum, nil] handle
        # @return [Array<Fixnum>, nil]
        # @since 3.8.0
        def get_size(handle)
          rect = get_rect(handle)
          rect ? [rect[2] - rect[0], rect[3] - rect[1]] : nil
        end

        # Move or resize a window.
        # @return [Boolean] false - not supported by the fallback implementation.
        # @since 3.8.0
        def set_pos(*args)
          false
        end

        # Resize a window.
        # @return [Boolean] false - not supported by the fallback implementation.
        # @since 3.8.0
        def set_size(*args)
          false
        end

        # Show or hide a window.
        # @param [Fixnum, nil] handle
        # @param [Fixnum] cmd_show
        # @return [Boolean] success
        # @since 3.8.0
        def show(handle, cmd_show)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'ShowWindow',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT,
            handle, cmd_show.to_i)
          !result.nil?
        rescue StandardError
          false
        end

        # Determine whether a window is visible.
        # @param [Fixnum, nil] handle
        # @return [Boolean]
        # @since 3.8.0
        def is_visible?(handle)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'IsWindowVisible',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle)
          result.to_i != 0
        rescue StandardError
          false
        end

        # Determine whether a window is minimized.
        # @param [Fixnum, nil] handle
        # @return [Boolean]
        # @since 3.8.0
        def is_minimized?(handle)
          is_iconic_or_zoomed(handle, 'IsIconic')
        end

        # Determine whether a window is maximized.
        # @param [Fixnum, nil] handle
        # @return [Boolean]
        # @since 3.8.0
        def is_maximized?(handle)
          is_iconic_or_zoomed(handle, 'IsZoomed')
        end

        # Determine whether a window is in the normal (restored) state.
        # @param [Fixnum, nil] handle
        # @return [Boolean]
        # @since 3.8.0
        def is_restored?(handle)
          return false unless handle.is_a?(Integer) && handle != 0
          !is_minimized?(handle) && !is_maximized?(handle)
        end

        # Determine whether a window is the active window.
        # @param [Fixnum, nil] handle
        # @return [Boolean]
        # @since 3.8.0
        def is_active?(handle)
          return false unless handle.is_a?(Integer) && handle != 0
          active = AMS::FallbackHelper.call_win32('user32', 'GetActiveWindow',
            [], Fiddle::TYPE_VOIDP)
          !active.nil? && active.to_i == handle
        rescue StandardError
          false
        end

        # Close a window.
        # @param [Fixnum, nil] handle
        # @return [Boolean] success
        # @since 3.8.0
        def close(handle)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'PostMessageW',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
            Fiddle::TYPE_INT, handle, 0x0010, 0, 0) # WM_CLOSE
          !result.nil?
        rescue StandardError
          false
        end

        # Set the attributes of a layered window.
        # @param [Fixnum, nil] handle
        # @param [Fixnum] color_key
        # @param [Fixnum] alpha
        # @param [Fixnum] flags
        # @return [Boolean] success
        # @since 3.8.0
        def set_layered_attributes(handle, color_key, alpha, flags)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'SetLayeredWindowAttributes',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_CHAR, Fiddle::TYPE_INT],
            Fiddle::TYPE_INT, handle, color_key.to_i, alpha.to_i, flags.to_i)
          !result.nil? && result != 0
        rescue StandardError
          false
        end

        # Set the parent of a window.
        # @return [Boolean] false - not supported by the fallback implementation.
        # @since 3.8.0
        def set_parent(*args)
          false
        end

        # Bring a window to the top of the Z order.
        # @param [Fixnum, nil] handle
        # @return [Boolean] success
        # @since 3.8.0
        def bring_to_top(handle)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', 'SetForegroundWindow',
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle)
          result.to_i != 0
        rescue StandardError
          false
        end

        private

        def rect_from(handle)
          return nil unless handle.is_a?(Integer) && handle != 0
          buffer = [0, 0, 0, 0].pack('l<l<l<l<')
          ptr = Fiddle::Pointer[buffer]
          result = AMS::FallbackHelper.call_win32('user32', 'GetWindowRect',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle, ptr)
          return nil if result.nil? || result == 0
          buffer.unpack('l<l<l<l<')
        rescue StandardError
          nil
        end

        def is_iconic_or_zoomed(handle, function)
          return false unless handle.is_a?(Integer) && handle != 0
          result = AMS::FallbackHelper.call_win32('user32', function,
            [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT, handle)
          result.to_i != 0
        rescue StandardError
          false
        end

      end # class << self
    end # module Window
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Sketchup
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Sketchup, false)
  module AMS
    # SketchUp frame management.
    #
    # @note SketchUp 2024 and later use a Qt based frame. Features that
    #   require subclassing or reparenting SketchUp's windows - switching
    #   fullscreen, embedding a dialog into the viewport, hiding the trays,
    #   status bar, and the menu bar - are no longer available through the
    #   Windows API. The corresponding functions are no-ops here, and callers
    #   are expected to fall back to the standard SketchUp Ruby API.
    # @since 3.8.0
    module Sketchup

      @observers = []

      class << self

        # Get the handle of SketchUp's main window.
        # @note The handle of the main window cannot be retrieved from Ruby
        #   since SketchUp 2024.
        # @return [Fixnum] +0+ - unsupported
        # @since 3.8.0
        def get_main_window
          0
        end

        # Determine whether SketchUp's main window is active.
        # @return [Boolean]
        # @since 3.8.0
        def is_main_window_active?
          return true unless AMS::FallbackHelper::WIN32_AVAILABLE
          foreground = AMS::FallbackHelper.call_win32('user32', 'GetForegroundWindow',
            [], Fiddle::TYPE_VOIDP)
          return true if foreground.nil?
          foreground = foreground.to_i
          return true if foreground == 0
          pid = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
          AMS::FallbackHelper.call_win32('user32', 'GetWindowThreadProcessId',
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG, foreground, pid)
          foreground_pid = pid[0, Fiddle::SIZEOF_INT].unpack('L<')[0]
          current_pid = AMS::FallbackHelper.call_win32('kernel32', 'GetCurrentProcessId',
            [], Fiddle::TYPE_LONG)
          return true if current_pid.nil? || foreground_pid.nil?
          foreground_pid == current_pid
        rescue StandardError
          true
        end

        # Find a window by its caption.
        # @note Unsupported since SketchUp 2024; returns +nil+ so that callers
        #   fall back to the standard SketchUp Ruby API.
        # @return [nil]
        # @since 3.8.0
        def find_window_by_caption(caption = nil)
          nil
        end

        # Get the caption of a window.
        # @return [String] an empty string
        # @since 3.8.0
        def get_caption(handle = nil)
          ''
        end

        # Set the caption of a window.
        # @return [Boolean] false
        # @since 3.8.0
        def set_caption(*args)
          false
        end

        # Activate SketchUp's main window.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def activate
          false
        end

        # Deactivate SketchUp's main window.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def deactivate
          false
        end

        # Refresh the SketchUp window.
        # @return [Boolean] true
        # @since 3.8.0
        def refresh
          true
        end

        # Display a messagebox without blocking the calling code. The
        # messagebox is displayed by a timer, which allows the current
        # operation, e.g. an animation export, to keep running. When the
        # messagebox is dismissed, the given block is called.
        # @param [String] caption Caption of the messagebox. SketchUp does not
        #   support captions on messageboxes, so it is only used for
        #   reference.
        # @param [String, nil] message Message to display.
        # @param [Fixnum] type Messagebox type, e.g. +MB_OK+.
        # @yieldparam [Fixnum] result The value returned by the messagebox.
        # @return [Fixnum] +0+
        # @since 3.8.0
        def threaded_messagebox(caption, message = nil, type = MB_OK, &block)
          if message.nil?
            message = caption
            caption = ''
          end
          message = message.to_s.dup
          type = type.to_i
          ::UI.start_timer(0.05, false) {
            result = ::UI.messagebox(message, type)
            block.call(result) if block
          }
          0
        end

        # Display a messagebox.
        # @param [String, nil] caption Caption of the messagebox.
        # @param [String] message Message to display.
        # @param [Fixnum] type Messagebox type, e.g. +MB_OK+.
        # @return [Fixnum] The value returned by the messagebox.
        # @since 3.8.0
        def messagebox(caption, message = nil, type = MB_OK)
          if message.nil?
            message = caption
            caption = ''
          end
          ::UI.messagebox(message.to_s, type.to_i)
        end

        # Include a dialog into SketchUp's frame.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def include_dialog(*args)
          false
        end

        # Exclude a dialog from SketchUp's frame.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def exclude_dialog(*args)
          false
        end

        # Ignore a dialog by the window manager.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def ignore_dialog(*args)
          false
        end

        # Add an observer.
        # @param [Object] observer
        # @return [Boolean] success
        # @since 3.8.0
        def add_observer(observer)
          return false if observer.nil?
          @observers << observer unless @observers.include?(observer)
          true
        end

        # Remove an observer.
        # @param [Object] observer
        # @return [Boolean] success
        # @since 3.8.0
        def remove_observer(observer)
          @observers.delete(observer)
          true
        end

        # Get all the observers.
        # @return [Array<Object>]
        # @since 3.8.0
        def get_observers
          @observers.dup
        end

        # Show or hide the trays.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_trays(*args)
          false
        end

        # Show or hide the toolbars.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_toolbars(*args)
          false
        end

        # Show or hide the toolbar container.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_toolbar_container(*args)
          false
        end

        # Show or hide the status bar.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_status_bar(*args)
          false
        end

        # Show or hide the scenes bar.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_scenes_bar(*args)
          false
        end

        # Show or hide the dialogs/trays.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def show_dialogs(*args)
          false
        end

        # Show or hide the menu bar.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def set_menu_bar(*args)
          false
        end

        # Show or hide the viewport border.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def set_viewport_border(*args)
          false
        end

        # Switch SketchUp in or out of the fullscreen mode.
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def switch_full_screen(*args)
          false
        end

        # Get the rectangle of the viewport, as
        # +[left, top, right, bottom]+, in screen coordinates.
        # @return [Array<Fixnum>]
        # @since 3.8.0
        def get_viewport_rect(*args)
          model = ::Sketchup.active_model
          view = model ? model.active_view : nil
          if view
            [0, 0, view.vpwidth.to_i, view.vpheight.to_i]
          else
            [0, 0, 0, 0]
          end
        end

        # Activate a tab of the scenes bar.
        # @param [Fixnum] index
        # @return [Boolean] false - unsupported
        # @since 3.8.0
        def activate_scenes_bar_tab(index)
          false
        end

        # Convert a point from the screen coordinates into the coordinates of
        # SketchUp's main window.
        # @return [Array<Fixnum>, nil] +nil+ - unsupported
        # @since 3.8.0
        def screen_to_client(*args)
          nil
        end

        # Convert a point from the coordinates of SketchUp's main window into
        # the screen coordinates.
        # @return [Array<Fixnum>, nil] +nil+ - unsupported
        # @since 3.8.0
        def client_to_screen(*args)
          nil
        end

      end # class << self
    end # module Sketchup
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Group
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Group, false)
  module AMS
    # Helpers for working with groups and component instances.
    # @note This is a pure Ruby implementation of the native functions. The
    #   returned geometry is expressed in the coordinate system of the given
    #   entity's definition, with the transformations of the nested entities
    #   applied to it. The transformation of the entity itself is not applied,
    #   matching the behaviour of the native implementation.
    # @since 3.8.0
    module Group

      class << self

        # Get the definition of a group or a component instance.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance, MSPhysics::Body] entity
        # @return [::Sketchup::ComponentDefinition]
        # @since 3.8.0
        def get_definition(entity)
          entity = entity.group if entity.respond_to?(:group) && !entity.is_a?(::Sketchup::Group) && !entity.is_a?(::Sketchup::ComponentInstance)
          if entity.is_a?(::Sketchup::Group) || entity.is_a?(::Sketchup::ComponentInstance)
            entity.definition
          else
            entity
          end
        end

        # Get the entities of a group, a component instance, or a body.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance, ::Sketchup::Model, MSPhysics::Body] entity
        # @return [::Sketchup::Entities]
        # @since 3.8.0
        def get_entities(entity)
          entity = entity.group if entity.respond_to?(:group) && !entity.is_a?(::Sketchup::Group) && !entity.is_a?(::Sketchup::ComponentInstance)
          case entity
          when ::Sketchup::Group, ::Sketchup::ComponentInstance
            entity.definition.entities
          when ::Sketchup::Model
            entity.entities
          else
            entity.respond_to?(:entities) ? entity.entities : entity
          end
        end

        # Collect all the faces of an entity, recursively, excluding the
        # entities that fail the validation proc.
        # @api private
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Proc, nil] validation_proc
        # @return [Array<::Sketchup::Face>]
        # @since 3.8.0
        def collect_faces(entity, validation_proc)
          entities = get_entities(entity)
          return [] unless entities.respond_to?(:each)
          faces = []
          entities.each { |e|
            if e.is_a?(::Sketchup::Group) || e.is_a?(::Sketchup::ComponentInstance)
              next unless validation_proc.nil? || validation_proc.call(e)
              faces.concat(collect_faces(e, validation_proc))
            elsif e.is_a?(::Sketchup::Face)
              faces << e
            end
          }
          faces
        end

        # Compute the transformation from the definition of +entity+ down to
        # the given nested entities.
        # @api private
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @return [Array<Array>] An array of +[transformation, entities]+ pairs,
        #   in the local space of the given entity's definition.
        # @since 3.8.0
        def collect_face_groups(entity, validation_proc)
          groups = []
          walk = lambda { |container, transformation|
            entities = get_entities(container)
            return unless entities.respond_to?(:each)
            faces = []
            entities.each { |e|
              if e.is_a?(::Sketchup::Group) || e.is_a?(::Sketchup::ComponentInstance)
                next unless validation_proc.nil? || validation_proc.call(e)
                walk.call(e, transformation * e.transformation)
              elsif e.is_a?(::Sketchup::Face)
                faces << e
              end
            }
            groups << [transformation, faces] unless faces.empty?
          }
          walk.call(entity, ::Geom::Transformation.new())
          groups
        end

        # Get the bounding box of the faces of an entity.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation An additional
        #   transformation to apply to the points.
        # @param [Proc, nil] validation_proc Proc used to filter nested
        #   entities; returns true when the entities of the given group or
        #   component instance are to be included.
        # @return [::Geom::BoundingBox]
        # @since 3.8.0
        def get_bounding_box_from_faces(entity, use_current_tra = true, transformation = nil, &validation_proc)
          bb = ::Geom::BoundingBox.new()
          each_face_point(entity, transformation, validation_proc) { |point| bb.add(point) }
          bb
        end

        # Get the vertices of the faces of an entity.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation
        # @param [Proc, nil] validation_proc
        # @return [Array<::Geom::Point3d>] An array of unique points.
        # @since 3.8.0
        def get_vertices_from_faces(entity, use_current_tra = true, transformation = nil, &validation_proc)
          points = []
          seen = {}
          each_face_point(entity, transformation, validation_proc) { |point|
            key = [point.x.to_f.round(6), point.y.to_f.round(6), point.z.to_f.round(6)]
            next if seen[key]
            seen[key] = true
            points << point
          }
          points
        end

        # Get the vertices of the faces of an entity, grouped by the nested
        # entity they belong to. Used for generating compound collisions.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation
        # @param [Proc, nil] validation_proc
        # @return [Array<Array<::Geom::Point3d>>]
        # @since 3.8.0
        def get_vertices_from_faces2(entity, use_current_tra = true, transformation = nil, &validation_proc)
          collections = []
          collect_face_groups(entity, validation_proc).each { |tra, faces|
            points = []
            seen = {}
            faces.each { |face|
              face.vertices.each { |vertex|
                point = vertex.position
                point = point.transform(tra)
                point = point.transform(transformation) if transformation
                key = [point.x.to_f.round(6), point.y.to_f.round(6), point.z.to_f.round(6)]
                next if seen[key]
                seen[key] = true
                points << point
              }
            }
            collections << points unless points.empty?
          }
          collections
        end

        # Triangulate the faces of an entity, returning the resulting
        # polygons as arrays of points.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation
        # @param [Proc, nil] validation_proc
        # @return [Array<Array<::Geom::Point3d>>] An array of triangles.
        # @since 3.8.0
        def get_polygons_from_faces(entity, use_current_tra = true, transformation = nil, &validation_proc)
          triplets = []
          each_triplet(entity, transformation, validation_proc) { |triplet| triplets << triplet }
          triplets
        end

        # Get a polygon mesh of the faces of an entity.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation
        # @param [Proc, nil] validation_proc
        # @return [::Geom::PolygonMesh]
        # @since 3.8.0
        def get_triangular_mesh(entity, use_current_tra = true, transformation = nil, &validation_proc)
          mesh = ::Geom::PolygonMesh.new(0, 0, 0)
          each_triplet(entity, transformation, validation_proc) { |triplet|
            mesh.add_polygon(*triplet)
          }
          mesh
        end

        # Get a polygon mesh for every nested entity of an entity.
        # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
        # @param [Boolean] use_current_tra Accepted for compatibility.
        # @param [::Geom::Transformation, nil] transformation
        # @param [Proc, nil] validation_proc
        # @return [Array<::Geom::PolygonMesh>]
        # @since 3.8.0
        def get_triangular_meshes(entity, use_current_tra = true, transformation = nil, &validation_proc)
          meshes = []
          collect_face_groups(entity, validation_proc).each { |tra, faces|
            mesh = ::Geom::PolygonMesh.new(0, 0, 0)
            count = 0
            faces.each { |face|
              triangulate(face).each { |triplet|
                points = triplet.map { |point|
                  p = point.transform(tra)
                  transformation ? p.transform(transformation) : p
                }
                mesh.add_polygon(*points)
                count += 1
              }
            }
            meshes << mesh if count > 0
          }
          meshes
        end

        private

        # Iterate over the points of every face of an entity.
        def each_face_point(entity, transformation, validation_proc)
          collect_face_groups(entity, validation_proc).each { |tra, faces|
            faces.each { |face|
              face.vertices.each { |vertex|
                point = vertex.position.transform(tra)
                point = point.transform(transformation) if transformation
                yield(point)
              }
            }
          }
        end

        # Iterate over the triangulated faces of an entity, yielding triangles
        # as arrays of points.
        def each_triplet(entity, transformation, validation_proc)
          collect_face_groups(entity, validation_proc).each { |tra, faces|
            faces.each { |face|
              triangulate(face).each { |triplet|
                points = triplet.map { |point|
                  p = point.transform(tra)
                  transformation ? p.transform(transformation) : p
                }
                yield(points)
              }
            }
          }
        end

        # Triangulate a single face, returning its triangles as arrays of
        # three points, expressed in the coordinate system of the face's
        # parent entities.
        def triangulate(face)
          triplets = []
          mesh = face.mesh(1 | 4) # PolygonMeshPoints | PolygonMeshPolygons
          mesh.polygons.each { |polygon|
            points = polygon.map { |index| mesh.point_at(index.to_i.abs) }
            # Fan triangulation of the (usually convex) polygon.
            if points.size >= 3
              for i in 1...(points.size - 1)
                triplets << [points[0], points[i], points[i + 1]]
              end
            end
          }
          triplets
        rescue StandardError
          # Fallback: triangulate the face by its outer loop.
          points = face.outer_loop.vertices.map { |vertex| vertex.position }
          triplets = []
          if points.size >= 3
            for i in 1...(points.size - 1)
              triplets << [points[0], points[i], points[i + 1]]
            end
          end
          triplets
        end

      end # class << self
    end # module Group
  end # module AMS
end


# ---------------------------------------------------------------------------
# AMS::Geometry
# ---------------------------------------------------------------------------
unless AMS.const_defined?(:Geometry, false)
  module AMS
    # Geometry and math helpers.
    # @since 3.8.0
    module Geometry

      class << self

        # Scale a vector.
        # @param [::Geom::Vector3d] vector
        # @param [Numeric, ::Geom::Vector3d] scale
        # @return [::Geom::Vector3d]
        # @since 3.8.0
        def scale_vector(vector, scale)
          if scale.is_a?(Numeric)
            ::Geom::Vector3d.new(vector.x * scale, vector.y * scale, vector.z * scale)
          else
            ::Geom::Vector3d.new(vector.x * scale.x, vector.y * scale.y, vector.z * scale.z)
          end
        end

        # Scale a point.
        # @param [::Geom::Point3d] point
        # @param [Numeric, ::Geom::Vector3d] scale
        # @return [::Geom::Point3d]
        # @since 3.8.0
        def scale_point(point, scale)
          if scale.is_a?(Numeric)
            ::Geom::Point3d.new(point.x * scale, point.y * scale, point.z * scale)
          else
            ::Geom::Point3d.new(point.x * scale.x, point.y * scale.y, point.z * scale.z)
          end
        end

        # Get the scale of a transformation matrix, as a vector holding the
        # length of the matrix axes.
        # @param [::Geom::Transformation] transformation
        # @return [::Geom::Vector3d]
        # @since 3.8.0
        def get_matrix_scale(transformation)
          ::Geom::Vector3d.new(
            transformation.xaxis.length.to_f,
            transformation.yaxis.length.to_f,
            transformation.zaxis.length.to_f
          )
        end

        # Determine whether a transformation matrix is flipped, i.e. whether
        # the determinant of its rotational/scale part is negative.
        # @param [::Geom::Transformation] transformation
        # @return [Boolean]
        # @since 3.8.0
        def is_matrix_flipped?(transformation)
          x = transformation.xaxis
          y = transformation.yaxis
          z = transformation.zaxis
          det = x.x.to_f * (y.y.to_f * z.z.to_f - y.z.to_f * z.y.to_f) -
                y.x.to_f * (x.y.to_f * z.z.to_f - x.z.to_f * z.y.to_f) +
                z.x.to_f * (x.y.to_f * y.z.to_f - x.z.to_f * y.y.to_f)
          det < 0.0
        end

        # Determine whether a transformation matrix is uniform, i.e. whether
        # its axes are perpendicular to each other and have the same length.
        # @param [::Geom::Transformation] transformation
        # @param [Numeric] tolerance
        # @return [Boolean]
        # @since 3.8.0
        def is_matrix_uniform?(transformation, tolerance = 1.0e-6)
          x = transformation.xaxis
          y = transformation.yaxis
          z = transformation.zaxis
          # Perpendicularity
          return false if x.dot(y).abs > tolerance * x.length * y.length
          return false if x.dot(z).abs > tolerance * x.length * z.length
          return false if y.dot(z).abs > tolerance * y.length * z.length
          # Uniformity of the scale
          xlen = x.length.to_f
          ylen = y.length.to_f
          zlen = z.length.to_f
          return false if (xlen - ylen).abs > tolerance * (xlen + ylen)
          return false if (xlen - zlen).abs > tolerance * (xlen + zlen)
          true
        end

        # Extract the scale of a transformation matrix into a transformation
        # matrix that only holds the scale.
        # @param [::Geom::Transformation] transformation
        # @return [::Geom::Transformation]
        # @since 3.8.0
        def extract_matrix_scale(transformation)
          scale = get_matrix_scale(transformation)
          flipped = is_matrix_flipped?(transformation)
          sx = flipped ? -scale.x : scale.x
          ::Geom::Transformation.new([sx, 0, 0, 0, 0, scale.y, 0, 0, 0, 0, scale.z, 0, 0, 0, 0, 1])
        end

        # Determine whether a set of points is coplanar.
        # @param [Array<::Geom::Point3d>] points
        # @param [Numeric] tolerance
        # @return [Boolean]
        # @since 3.8.0
        def points_coplanar?(points, tolerance = 1.0e-6)
          return true if points.size < 4
          p1 = points[0]
          # Find three non-collinear points
          p2 = nil
          p3 = nil
          points.each { |point|
            next if point.distance(p1) <= tolerance
            p2 = point
            break
          }
          return true unless p2
          normal = nil
          points.each { |point|
            next if point.distance(p1) <= tolerance || point.distance(p2) <= tolerance
            n = (p2 - p1).cross(point - p1)
            next if n.length <= tolerance
            normal = n.normalize
            p3 = point
            break
          }
          return true unless normal
          points.each { |point|
            return false if (point - p1).dot(normal).abs > tolerance
          }
          true
        end

        # Interpolate between two numbers.
        # @param [Numeric] start
        # @param [Numeric] finish
        # @param [Numeric] factor
        # @return [Numeric]
        # @since 3.8.0
        def transition_number(start, finish, factor)
          start + (finish - start) * factor
        end

        # Interpolate between two vectors.
        # @param [::Geom::Vector3d] start
        # @param [::Geom::Vector3d] finish
        # @param [Numeric] factor
        # @return [::Geom::Vector3d]
        # @since 3.8.0
        def transition_vector(start, finish, factor)
          ::Geom::Vector3d.new(
            start.x + (finish.x - start.x) * factor,
            start.y + (finish.y - start.y) * factor,
            start.z + (finish.z - start.z) * factor
          )
        end

        # Interpolate between two points.
        # @param [::Geom::Point3d] start
        # @param [::Geom::Point3d] finish
        # @param [Numeric] factor
        # @return [::Geom::Point3d]
        # @since 3.8.0
        def transition_point(start, finish, factor)
          ::Geom::Point3d.new(
            start.x + (finish.x - start.x) * factor,
            start.y + (finish.y - start.y) * factor,
            start.z + (finish.z - start.z) * factor
          )
        end

        # Interpolate between two colors.
        # @param [::Sketchup::Color] start
        # @param [::Sketchup::Color] finish
        # @param [Numeric] factor
        # @return [::Sketchup::Color]
        # @since 3.8.0
        def transition_color(start, finish, factor)
          ::Sketchup::Color.new(
            (start.red + (finish.red - start.red) * factor).round,
            (start.green + (finish.green - start.green) * factor).round,
            (start.blue + (finish.blue - start.blue) * factor).round,
            start.alpha
          )
        end

        # Interpolate between two cameras.
        # @param [::Sketchup::Camera] start
        # @param [::Sketchup::Camera] finish
        # @param [Numeric] factor
        # @return [::Sketchup::Camera]
        # @since 3.8.0
        def transition_camera(start, finish, factor)
          eye = transition_point(start.eye, finish.eye, factor)
          target = transition_point(start.target, finish.target, factor)
          up = transition_vector(start.up, finish.up, factor).normalize
          up = Z_AXIS if up.length.to_f < 1.0e-6
          camera = ::Sketchup::Camera.new(eye, target, up)
          camera.perspective = start.perspective?
          if start.perspective?
            camera.fov = transition_number(start.fov, finish.fov, factor)
          else
            camera.height = transition_number(start.height, finish.height, factor)
          end
          camera
        rescue StandardError
          start
        end

        # Interpolate between two transformations.
        # @param [::Geom::Transformation] start
        # @param [::Geom::Transformation] finish
        # @param [Numeric] factor
        # @return [::Geom::Transformation]
        # @since 3.8.0
        def transition_transformation(start, finish, factor)
          origin = transition_point(start.origin, finish.origin, factor)
          xaxis = transition_vector(start.xaxis, finish.xaxis, factor)
          yaxis = transition_vector(start.yaxis, finish.yaxis, factor)
          zaxis = transition_vector(start.zaxis, finish.zaxis, factor)
          ::Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
        rescue StandardError
          start
        end

        # Compute a point on a cubic Bezier curve.
        # @param [::Geom::Point3d] p0
        # @param [::Geom::Point3d] p1
        # @param [::Geom::Point3d] p2
        # @param [::Geom::Point3d] p3
        # @param [Numeric] t
        # @return [::Geom::Point3d]
        # @since 3.8.0
        def calc_cubic_bezier_point(p0, p1, p2, p3, t)
          t = t.to_f
          mt = 1.0 - t
          a = mt * mt * mt
          b = 3.0 * mt * mt * t
          c = 3.0 * mt * t * t
          d = t * t * t
          ::Geom::Point3d.new(
            a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            a * p0.y + b * p1.y + c * p2.y + d * p3.y,
            a * p0.z + b * p1.z + c * p2.z + d * p3.z
          )
        end

        # Compute a tangent of a cubic Bezier curve.
        # @param [::Geom::Point3d] p0
        # @param [::Geom::Point3d] p1
        # @param [::Geom::Point3d] p2
        # @param [::Geom::Point3d] p3
        # @param [Numeric] t
        # @return [::Geom::Vector3d]
        # @since 3.8.0
        def calc_cubic_bezier_tangent(p0, p1, p2, p3, t)
          t = t.to_f
          mt = 1.0 - t
          a = 3.0 * mt * mt
          b = 6.0 * mt * t
          c = 3.0 * t * t
          ::Geom::Vector3d.new(
            a * (p1.x - p0.x) + b * (p2.x - p1.x) + c * (p3.x - p2.x),
            a * (p1.y - p0.y) + b * (p2.y - p1.y) + c * (p3.y - p2.y),
            a * (p1.z - p0.z) + b * (p2.z - p1.z) + c * (p3.z - p2.z)
          )
        end

        # Get the closest point on a line to the given point.
        # @param [::Geom::Point3d] point
        # @param [::Geom::Point3d] line_start
        # @param [::Geom::Point3d] line_end
        # @return [::Geom::Point3d]
        # @since 3.8.0
        def closest_point_on_line(point, line_start, line_end)
          line = line_end - line_start
          len = line.length.to_f
          return ::Geom::Point3d.new(line_start) if len < 1.0e-12
          dir = line.normalize
          dist = (point - line_start).dot(dir)
          ::Geom::Point3d.new(
            line_start.x + dir.x * dist,
            line_start.y + dir.y * dist,
            line_start.z + dir.z * dist
          )
        end

      end # class << self
    end # module Geometry
  end # module AMS
end
