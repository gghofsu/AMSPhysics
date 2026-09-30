# Harness test: the libraries of the engine that are shipped with the
# extension.
#
# Windows does not look for the libraries a library depends on in the folder of
# that library: they have to be loadable into the process beforehand, which is
# what AMS::ExtensionManager#require_all does. A dependency that is not shipped
# makes the library that needs it fail to load, and Windows only reports
# "The specified module could not be found" in that case, which does not name
# the library that is missing. This test catches such gaps.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_dll_files.rb
$stdout.sync = true

require 'sketchup.rb'
require 'MSPhysics.rb'
require 'ams_lib.rb'
require 'ams_lib/main'

STAGE = '/MSPhysics/libraries/stage/win64'
ABI = RUBY_VERSION[0..2].to_s

# Libraries of Windows itself, which are always available.
SYSTEM_LIBRARIES = %w[
  KERNEL32 USER32 GDI32 ADVAPI32 SHELL32 OLE32 OLEAUT32 WINMM IMM32 VERSION
  DSOUND MSVCRT OLEACC COMCTL32 COMDLG32 WS2_32
].freeze

def system_library?(name)
  upper = name.to_s.upcase
  return true if upper.start_with?('API-MS-')
  SYSTEM_LIBRARIES.include?(upper.sub(/\.DLL\z/, ''))
end

failures = []
$checks = 0

def check(failures, label)
  result = yield
  $checks += 1
  puts format('  ok   %-58s => %s', label, result.inspect[0, 56])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-58s !! %s: %s', label, err.class, err.message)
  nil
end

puts "== libraries shipped for Ruby #{ABI} =="

files = Dir.entries(STAGE).select { |entry| entry =~ /\.dll\z/i }.sort
puts "   #{files.size} libraries: #{files.join(', ')}"

check(failures, 'the required libraries are shipped') {
  missing = %w[newton.dll SDL2.dll SDL2_mixer.dll].reject { |name| files.include?(name) }
  missing.empty? ? true : "missing: #{missing.join(', ')}"
}

check(failures, "the engine for Ruby #{ABI} is shipped") {
  File.exist?(File.join(STAGE, ABI, 'msp_lib.so'))
}

puts '== dependencies of the shipped libraries =='
files.each { |name|
  path = File.join(STAGE, name)
  dependencies = AMS::DLL.dependencies(path)
  next if dependencies.empty?
  missing = dependencies.reject { |dependency|
    system_library?(dependency) ||
      File.exist?(File.join(STAGE, dependency)) ||
      File.exist?(File.join(STAGE, ABI, dependency))
  }
  check(failures, "#{name} has all of its libraries") {
    missing.empty? ? true : "MISSING: #{missing.join(', ')}"
  }
}

puts '== the engine of this Ruby =='
engine = File.join(STAGE, ABI, 'msp_lib.so')
check(failures, 'the libraries of the engine are all shipped') {
  AMS::DLL.dependencies(engine).reject { |name|
    system_library?(name) || files.include?(name)
  }
}
# The harness runs on wasm Ruby, so its Ruby library is not the one the engine
# is built against; the check of the mismatch is only informational here.
puts "   note: engine built against #{AMS::DLL.imported_ruby_libraries(engine).inspect}, " \
     "this Ruby is #{AMS::DLL.ruby_library_name.inspect}"
if AMS::DLL.ruby_library_name == 'x64-ucrt-ruby320.dll'
  check(failures, 'no mismatch for the Ruby library of SketchUp 2024-2026') {
    AMS::DLL.ruby_library_mismatch(engine).nil?
  }
end

puts
if failures.empty?
  puts "== ALL #{$checks} LIBRARY FILE CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
