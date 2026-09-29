# Harness test: exercise the AMS::ExtensionManager staging logic with the real
# files of this repository, i.e. the code path that runs when SketchUp loads
# MSPhysics.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_extension_manager.rb
$stdout.sync = true

require 'sketchup.rb'
require 'MSPhysics.rb'   # for MSPhysics::VERSION
require 'ams_lib.rb'
require 'ams_lib/main'

failures = []
$checks = 0

def check(failures, label)
  result = yield
  $checks += 1
  puts format('  ok   %-56s => %s', label, result.inspect[0, 60])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-56s !! %s: %s', label, err.class, err.message)
  nil
end

EXT_DIR = '/MSPhysics'
VERSION = MSPhysics::VERSION
ABI = RUBY_VERSION[0..2].to_s
STAGE_EXT = "#{EXT_DIR}/libraries/stage/win64"
VERSION_LIB = "#{EXT_DIR}/libraries/#{VERSION}/win64"
VERSION_EXT = "#{VERSION_LIB}/#{ABI}"

puts "== AMS::ExtensionManager #{AMS::Lib::VERSION} / MSPhysics #{VERSION} / Ruby #{ABI} =="

manager = nil
check(failures, 'AMS::ExtensionManager.new') {
  manager = AMS::ExtensionManager.new(EXT_DIR, VERSION)
  manager.class
}

check(failures, "available_c_extension_abis('msp_lib')") { manager.available_c_extension_abis('msp_lib') }
check(failures, "c_extension_available?('msp_lib')") { manager.c_extension_available?('msp_lib') }

# Register the same files as MSPhysics/main.rb does.
check(failures, 'add libraries and ruby files') {
  %w[libFLAC-8 libmikmod-2 libmodplug-1 libogg libvorbis libvorbisfile-3].each { |name| manager.add_optional_library(name) }
  %w[SDL2 SDL2_mixer].each { |name| manager.add_required_library(name) }
  manager.add_optional_library('smpeg2')
  manager.add_required_library('newton')
  manager.add_c_extension('msp_lib')
  manager.add_ruby_no_require('main')
  manager.add_ruby_no_require('main_entry')
  manager.add_ruby('entity')
  manager.add_ruby('simulation')
  'ok'
}

check(failures, 'require_all') { manager.require_all && 'ok' }

puts '== staged files =='
check(failures, 'versioned dir created') { File.directory?(VERSION_EXT) }
check(failures, "msp_lib.so copied to #{VERSION_EXT}") { File.exist?("#{VERSION_EXT}/msp_lib.so") }
check(failures, "newton.dll copied to #{VERSION_LIB}") { File.exist?("#{VERSION_LIB}/newton.dll") }
check(failures, 'SDL2.dll copied') { File.exist?("#{VERSION_LIB}/SDL2.dll") }
check(failures, 'SDL2_mixer.dll copied') { File.exist?("#{VERSION_LIB}/SDL2_mixer.dll") }
check(failures, 'optional libFLAC-8.dll copied') { File.exist?("#{VERSION_LIB}/libFLAC-8.dll") }
check(failures, 'optional smpeg2.dll copied') { File.exist?("#{VERSION_LIB}/smpeg2.dll") }

check(failures, 'the Ruby 3.2 newton.dll is used, not the generic one') {
  abi_specific = File.binread("#{STAGE_EXT}/#{ABI}/newton.dll")
  generic = File.binread("#{STAGE_EXT}/newton.dll")
  copied = File.binread("#{VERSION_LIB}/newton.dll")
  { abi_specific: copied == abi_specific, generic: copied == generic }
}
check(failures, 'the msp_lib.so of the running Ruby is used') {
  File.binread("#{VERSION_EXT}/msp_lib.so") == File.binread("#{STAGE_EXT}/#{ABI}/msp_lib.so")
}

check(failures, 'clean_up(false)') { manager.clean_up(false) || 'ok' }

puts
if failures.empty?
  puts "== ALL #{$checks} EXTENSION MANAGER CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  exit 1
end
