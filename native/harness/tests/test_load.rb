# Harness test: load AMS Library and MSPhysics on a stubbed Ruby 3.2 / SketchUp
# 2026 environment, verifying the whole require chain and the AMS Library
# fallback for the native part.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_load.rb
$stdout.sync = true

# The harness provides the SketchUp API through native/harness/stubs.
require 'sketchup.rb'

if ARGV.include?('--simulate-abi')
  # No native engine is staged for this Ruby version yet (e.g. Ruby 3.4, which
  # SketchUp announced for a future release). Copy the 3.2 engine to the folder
  # of the running Ruby version so that the Ruby part can be exercised; the C
  # extension itself is stubbed out by this harness either way.
  require 'fileutils'
  stage = '/MSPhysics/libraries/stage/win64'
  source = File.join(stage, '3.2')
  target = File.join(stage, RUBY_VERSION[0..2])
  FileUtils.mkdir_p(target)
  Dir.entries(source).each { |entry|
    fpath = File.join(source, entry)
    FileUtils.cp(fpath, File.join(target, entry)) if File.file?(fpath)
  }
  puts "   (using the 3.2 engine as a stand-in for Ruby #{RUBY_VERSION[0..2]})"
end

failures = []
checks = 0

def check(failures, label)
  yield.tap { |result| puts format('  ok   %-52s => %s', label, result.inspect[0, 70]) }
  # rubocop:disable Lint/RescueException
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-52s !! %s: %s', label, err.class, err.message)
  nil
end

puts '== environment =='
puts "   Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "   SketchUp #{Sketchup.version} / API#{Sketchup.version_number} / 64bit=#{Sketchup.is_64bit?}"

puts '== require chain: MSPhysics.rb -> main_entry -> ams_lib -> MSPhysics/main =='

# A guard so that a failure of the require chain does not abort the script.
begin
  if ARGV.include?('--skip-abi-gate')
    # Used when running on a Ruby version for which no native engine is staged
    # (e.g. the announced Ruby 3.4): load the AMS Library and the extension
    # directly instead of going through the ABI gate of MSPhysics/main_entry.rb.
    require 'MSPhysics.rb'
    require 'ams_lib.rb'
    require 'ams_lib/main'
    require 'MSPhysics/main'
  else
    require 'MSPhysics.rb'
  end
rescue Exception => err
  puts "  FATAL require MSPhysics.rb: #{err.class}: #{err.message}"
  puts err.backtrace.first(6)
end

check(failures, 'MSPhysics::VERSION') { MSPhysics::VERSION }
check(failures, 'AMS::Lib::VERSION') { AMS::Lib::VERSION }
check(failures, 'AMS::RUBY_FALLBACK_LOADED') { AMS::RUBY_FALLBACK_LOADED }
check(failures, 'AMS::RUBY_ABI_VERSION') { AMS::RUBY_ABI_VERSION }
check(failures, 'AMS::IS_SKETCHUP_64BIT') { AMS::IS_SKETCHUP_64BIT }
check(failures, 'MSPhysics::Newton.get_version') { MSPhysics::Newton.get_version }
check(failures, 'MSPhysics::World') { MSPhysics::World }
check(failures, 'MSPhysics::Simulation') { MSPhysics::Simulation }
check(failures, 'MSPhysics::Settings.update_timestep') { MSPhysics::Settings.update_timestep }
check(failures, 'MSPhysics::JOINT_ID_TO_NAME.size') { MSPhysics::JOINT_ID_TO_NAME.size }
check(failures, 'MSPhysics.large_integer?(2**40)') { MSPhysics.large_integer?(2**40) }
check(failures, 'MSPhysics.invert_transform(invertible)') { MSPhysics.invert_transform(Geom::Transformation.translation(1, 1, 1)).class }
check(failures, 'MSPhysics.invert_transform(singular)') { MSPhysics.invert_transform(Geom::Transformation.scaling(0, 0, 0)).class }

puts '== scene change wrapper (SketchUp 2026 undoable scene properties) =='
model = Sketchup.active_model
begin
  MSPhysics.wrap_scene_change('Test Op') { model.pages.add('Test Page') }
  checks += 1
  puts "  ok   wrap_scene_change balanced the operation (depth=#{model.operation_depth})"
rescue Exception => err
  failures << "wrap_scene_change: #{err.class}: #{err.message}"
  puts "  FAIL wrap_scene_change: #{err.class}: #{err.message}"
end
check(failures, 'operation depth after wrap') { model.operation_depth }

puts '== reply for the extension panels =='
check(failures, 'MSPhysics::Dialog') { MSPhysics::Dialog }
check(failures, 'MSPhysics::ControlPanel') { MSPhysics::ControlPanel }
check(failures, 'MSPhysics::Simulation.respond_to?(:active?)') { MSPhysics::Simulation.respond_to?(:active?) }

puts
if failures.empty?
  puts '== LOAD CHAIN COMPLETED WITHOUT FAILURES =='
else
  puts "== #{failures.size} FAILURES =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
