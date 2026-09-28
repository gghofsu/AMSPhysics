begin
  require 'json'
rescue LoadError
  # AMS::Translate will not parse translations with Ruby versions 1.8
end

module AMS

  # Translate allows loading and controlling localization of strings.
  # @since 3.7.0
  # @note The translation module was changed in 3.7.0 from the strings format to JSON
  # @note Compatible with SU2014 or later
  class Translate

    # Load JSON translation strings.
    # @param [String] dir Path to the directory with translation files
    # @param [String] toolname Base name of the translation file.
    # @param [String, nil] locale Specific language to look for or
    #   <tt>nil</tt> to relent on current localization.
    # @note The extension of a translation file must end with <tt>.json</tt>.
    #   Toolname and locale must be separated with an underscore.
    #   Example: <tt>commands_ru.json</tt> or <tt>commands_pt-BR.json</tt>.
    #   File names are not case sensitive.
    # @note The commands within a translate file must following the
    #   <tt>"base language str": "locale language str"</tt> syntax.
    # @note No errors will be raised if a translation file is invalid.
    def initialize(dir, toolname, locale = nil)
      @strings = {}
      locale = ::Sketchup.get_locale unless locale

      fpath = ::File.join(dir.to_s, toolname + '_' + locale.to_s + '.json')
      fpath.force_encoding('UTF-8') unless AMS::IS_RUBY_VERSION_18
      return unless ::File.exists?(fpath)
      begin
        dat = nil
        ::File.open(fpath, 'r') { |fp|
          dat = fp.read
        }
        @strings = ::JSON.parse(dat)
      rescue Exception => err
        puts err
        puts err.backtrace
      end

      # TODO: Ensure printf formats exist in both strings.

    end

    attr_reader :strings

    # @param [String] k
    def get(k)
      k = k.to_s
      v = @strings[k]
      if v.nil?
        # ::Kernel.printf("Warning: Translation does not exist for: \"%s\"\n", k)
        return k.dup
      # elsif !k.empty? && v.is_a?(String) && v.empty?
        # ::Kernel.printf("Warning: Translation is empty for: \"%s\"\n", k)
      end
      return v.dup
    end

    alias_method(:[], :get)

    # Translate and format a string
    # @param [String] k Text
    # @param [Array<Object>] args `sprintf` arguments
    # @return [String]
    def sprintf(k, *args)
      v = self.get(k)
      ::Kernel.sprintf(v, *args)
    end

    # Convert text. Items enclosed in `TR` and double brackets are translated:
    # `TR{{my text}}`
    # @param [String] t1 Text to translate
    # @return [String]
    def convert_text(t1)
      t2 = ""
      i1 = 0
      i2 = nil
      len = t1.length
      while i1 < len
        i2 = t1.index("TR{{", i1)
        if (i2.nil?)
          t2 << t1[i1...len]
          break
        end
        t2 << t1[i1...i2]
        i1 = i2 + 4
        i2 = t1.index("}}", i1)
        if (i2.nil?)
          t2 << t1[(i1 - 4)...len]
          break
        end
        s1 = t1[i1...i2]
        s2 = self.get(s1)
        t2 << s2
        i1 = i2 + 2
      end
      return t2
    end

  end # class Translate
end # module AMS
