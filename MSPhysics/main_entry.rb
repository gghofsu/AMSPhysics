require 'MSPhysics.rb'

# Load and verify AMS Library.
#
# AMS Library consists of a Ruby part and a native (C extension) part. The
# native part has to be compiled for the very Ruby version the running
# SketchUp uses. AMS Library 3.8.0 and later ship with a pure Ruby fallback
# implementation of the native part, which is loaded automatically when there
# is no native build for the running Ruby version.
ams_library_loaded = false

begin
  begin
    require 'ams_Lib/main'
  rescue LoadError
    # Some installations place the library into a lower case folder. This
    # matters on case sensitive file systems.
    require 'ams_lib/main'
  end
  ams_library_loaded = AMS::Lib::VERSION.to_f >= 3.5
rescue LoadError
  ams_library_loaded = false
end

if ams_library_loaded
  dir = File.dirname(__FILE__)
  # Verify that there is a native build of the MSPhysics engine for the Ruby
  # version used by the running SketchUp.
  ops = AMS::IS_PLATFORM_WINDOWS ? 'win' : 'osx'
  bit = AMS::IS_SKETCHUP_64BIT ? '64' : '32'
  c_ext = AMS::IS_PLATFORM_WINDOWS ? '.so' : '.bundle'
  stage_dir = File.join(dir, 'libraries', 'stage', ops + bit)
  abi = RUBY_VERSION[0..2].to_s
  available_abis = File.directory?(stage_dir) ? Dir.entries(stage_dir).select { |entry|
    File.exist?(File.join(stage_dir, entry, 'msp_lib' + c_ext))
  }.sort : []
  if available_abis.include?(abi)
    require File.join(dir, 'main')
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
    msg << "\n\nThe extension will not be loaded."
    ::UI.messagebox(msg)
    false
  end
else
  msg = "MSPhysics requires AMS Library, version 3.5.0 or later! This extension will not be loaded with the library not installed or outdated. Would you like to navigate to the library's download page?"
  if ::UI.messagebox(msg, MB_YESNO) == IDYES
    ::UI.openURL('http://sketchucation.com/forums/viewtopic.php?f=323&t=55067#p499835')
  end
end
