require 'sketchup.rb'
require 'extensions.rb'

fpath = __FILE__.dup
fpath.force_encoding('UTF-8') if fpath.respond_to?(:force_encoding)

unless file_loaded?(fpath)
  file_loaded(fpath)

  module AMS
    # @since 1.0.0
    module Lib

      NAME = 'AMS Library'.freeze

      MAJOR_VERSION = 3.freeze
      MINOR_VERSION = 7.freeze
      PATCH_VERSION = 1.freeze
      DEVEL_VERSION = 1.freeze

      VERSION_INT = (MAJOR_VERSION * 1000 + MINOR_VERSION * 100 + PATCH_VERSION * 10 + DEVEL_VERSION).to_i
      VERSION = sprintf("%d.%d.%d%c", MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION, DEVEL_VERSION + 0x61).freeze

      RELEASE_YEAR_START = 2013.freeze
      RELEASE_YEAR_END = 2021.freeze
      RELEASE_DATE = '29 May 2021'.freeze

      # Create the extension.
      cfpath = __FILE__.dup
      cfpath.force_encoding('UTF-8') if cfpath.respond_to?(:force_encoding)
      efpath = ::File.expand_path('../ams_Lib/main', cfpath)
      @extension = ::SketchupExtension.new(NAME, efpath)

      # Attach some nice info.
      @extension.description = "A library of functions and utilities for interacting with SketchUp window and procedures. AMS Library is used by other extensions and does nothing on its own."
      @extension.version = VERSION
      if (RELEASE_YEAR_START == RELEASE_YEAR_END)
        @extension.copyright = "(C) #{RELEASE_YEAR_START} Anton Synytsia"
      else
        @extension.copyright = "(C) #{RELEASE_YEAR_START} - #{RELEASE_YEAR_END} Anton Synytsia"
      end
      @extension.creator = 'Anton Synytsia'

      # Register and load the extension on start-up.
      ::Sketchup.register_extension(@extension, true)

      class << self

        # @!attribute [r] extension
        # Get AMS Library extension.
        # @return [SketchupExtension]
        attr_reader :extension

      end # class << self
    end # module Lib
  end # module AMS
end
