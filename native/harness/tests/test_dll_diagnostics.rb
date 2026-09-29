# Harness test: the library loading diagnostics of AMS Library.
#
# The diagnostics have to work without calling the Windows API, because they
# are the tool of last resort when a library cannot be loaded on a machine
# where the Windows API cannot be called through Fiddle. The dependency list is
# read from the import table of the Portable Executable.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_dll_diagnostics.rb
$stdout.sync = true

require 'sketchup.rb'
require 'MSPhysics.rb'
require 'ams_lib.rb'
require 'ams_lib/main'

STAGE = '/MSPhysics/libraries/stage/win64/3.2'

failures = []
$checks = 0

def check(failures, label)
  result = yield
  $checks += 1
  puts format('  ok   %-56s => %s', label, result.inspect[0, 58])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-56s !! %s: %s', label, err.class, err.message)
  nil
end

puts '== import table of the engine =='
dependencies = check(failures, "dependencies(#{STAGE}/msp_lib.so)") { AMS::DLL.dependencies("#{STAGE}/msp_lib.so") }
check(failures, 'newton.dll is a dependency') { dependencies.include?('newton.dll') }
check(failures, 'SDL2.dll is a dependency') { dependencies.include?('SDL2.dll') }
check(failures, 'SDL2_mixer.dll is a dependency') { dependencies.include?('SDL2_mixer.dll') }
check(failures, 'the Ruby library is a dependency') { dependencies.any? { |name| name =~ /ruby\d+\.dll\z/ } }
check(failures, 'KERNEL32.dll is a dependency') { dependencies.include?('KERNEL32.dll') }
check(failures, 'there are no duplicates') { dependencies.uniq.size == dependencies.size }

check(failures, 'newton.dll of the generic engine') { AMS::DLL.dependencies('/MSPhysics/libraries/stage/win64/newton.dll').sort }
check(failures, 'a non Portable Executable yields nothing') { AMS::DLL.dependencies('/MSPhysics.rb').empty? }
check(failures, 'a missing file yields nothing') { AMS::DLL.dependencies('/no/such/file.dll').empty? }

puts '== dependency report =='
report = check(failures, 'describe_dependencies') { AMS::DLL.describe_dependencies("#{STAGE}/msp_lib.so", [STAGE]) }
check(failures, 'the report names newton.dll') { report.to_s.include?('newton.dll') }
check(failures, 'the report finds the libraries in the staging folder') {
  report.to_s.scan('file found at').size
}
check(failures, 'the report names the libraries that are missing') {
  report.to_s =~ /could not be found: .*ruby\d+\.dll/ ? true : false
}

puts '== loading =='
check(failures, "load_library_info('/no/such/file.dll')") { AMS::DLL.load_library_info('/no/such/file.dll') }
check(failures, "load_library_info on a file that is not a library") { AMS::DLL.load_library_info('/README.md') }
check(failures, "library_error of a missing library") { AMS::DLL.library_error('/no/such/file.dll') }
check(failures, "loaded?('kernel32.dll') without the Windows API") { AMS::DLL.loaded?('kernel32.dll') }
check(failures, 'FallbackHelper.last_error without the Windows API') { AMS::FallbackHelper.last_error }
check(failures, 'FallbackHelper.error_message without the Windows API') { AMS::FallbackHelper.error_message(126) }
check(failures, 'FallbackHelper.add_dll_directory without the Windows API') { AMS::FallbackHelper.add_dll_directory('C:/') }
check(failures, 'FallbackHelper.load_library_ex without the Windows API') { AMS::FallbackHelper.load_library_ex('C:/newton.dll', 0) }

puts '== the Ruby library the engine is built against =='
check(failures, 'imported_ruby_libraries(msp_lib.so)') { AMS::DLL.imported_ruby_libraries("#{STAGE}/msp_lib.so") }
check(failures, 'the Ruby library of a library without one') { AMS::DLL.imported_ruby_libraries("#{STAGE}/../newton.dll") }
check(failures, 'ruby_library_name') { AMS::DLL.ruby_library_name }
# Pretend that this SketchUp uses the Universal CRT build of Ruby 3.2, which
# is the one the staged engine is linked against.
original_so_name = ::RbConfig::CONFIG['RUBY_SO_NAME']
begin
  ::RbConfig::CONFIG['RUBY_SO_NAME'] = 'x64-ucrt-ruby320'
  check(failures, 'ruby_library_mismatch is quiet when the names match') {
    AMS::DLL.ruby_library_mismatch("#{STAGE}/msp_lib.so")
  }
  check(failures, 'ruby_library_name of a Universal CRT Ruby 3.2') { AMS::DLL.ruby_library_name }
  # Pretend that this SketchUp uses a Ruby library with a different name.
  ::RbConfig::CONFIG['RUBY_SO_NAME'] = 'x64-msvcrt-ruby320'
  check(failures, 'ruby_library_mismatch reports a mismatch') {
    AMS::DLL.ruby_library_mismatch("#{STAGE}/msp_lib.so")
  }
ensure
  ::RbConfig::CONFIG['RUBY_SO_NAME'] = original_so_name
end

puts
if failures.empty?
  puts "== ALL #{$checks} DLL DIAGNOSTIC CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
