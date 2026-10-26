# Harness test: the differences between the SketchUp versions that MSPhysics
# supports, on the two ends of the range:
#
#   * SketchUp 2026 (Ruby 3.2): Sketchup::ShadowInfo#[]= raises a KeyError for
#     an invalid or read-only key.
#   * SketchUp 2027 (Ruby 3.4): that was relaxed to a Ruby warning, and
#     UI.refresh_toolbars was deprecated.
#
# MSPhysics restores and transitions the whole shadow info collection on every
# frame, so a warning per read-only key per frame would flood the Ruby console
# on SketchUp 2027; MSPhysics.set_shadow_info has to suppress it and remember
# the key instead.
#
# The SketchUp version that is simulated comes from SU_VERSION (see
# native/harness/run_tests.sh). The checks adapt to it, so that both behaviours
# are covered by the two runs of the suite.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_sketchup_2027.rb
$stdout.sync = true

require 'sketchup.rb'

# Keep a reference to the original Warning.warn, before MSPhysics installs the
# filter that drops the warnings it suppresses.
ORIGINAL_WARNING_WARN = defined?(::Warning) ? ::Warning.method(:warn) : nil

require 'MSPhysics.rb'

$passed_warnings = []
if defined?(::Warning)
  # A singleton method of Warning itself is reached only after every module
  # that was prepended to it, i.e. only with the warnings that MSPhysics lets
  # through. Warnings of other code must not be affected by the extension.
  ::Warning.define_singleton_method(:warn) do |*args, **kwargs|
    $passed_warnings << args.first.to_s
    nil
  end
end

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

SU = Sketchup::VERSION_NUMBER
SU2027 = SU >= 27.0
model = Sketchup.active_model
shadow_info = model.shadow_info
# A key that the harness declares read-only (see stub_sketchup_api.rb).
read_only_key = Sketchup::ShadowInfo::READ_ONLY_KEYS.first

puts '== environment =='
puts "   SketchUp #{Sketchup::VERSION} (simulated), Ruby #{RUBY_VERSION}"
puts "   MSPhysics #{MSPhysics::VERSION}, AMS Library #{AMS::Lib::VERSION}"

puts
puts '== UI.refresh_toolbars (deprecated in SketchUp 2027) =='
# Whether the deprecated method may still be used is a decision of the library
# and does not depend on the platform, so it can be checked here even though
# the harness simulates Windows.
available = check(failures, 'AMS.ui_refresh_toolbars_available?') { AMS.ui_refresh_toolbars_available? }
if available == !SU2027
  puts "  ok   UI.refresh_toolbars is #{SU2027 ? 'reported as deprecated' : 'reported as available'} on SketchUp #{Sketchup::VERSION_MAJOR}"
else
  failures << "ui_refresh_toolbars_available? returned #{available.inspect} on SketchUp #{Sketchup::VERSION}"
  puts "  FAIL expected #{!SU2027} on SketchUp #{Sketchup::VERSION}"
end
$checks += 1

# On Windows AMS.refresh_toolbars has always been a no-op; on the other
# platforms it calls UI.refresh_toolbars, unless SketchUp deprecated it.
calls_before = UI.refresh_toolbars_calls
AMS.refresh_toolbars
calls = UI.refresh_toolbars_calls - calls_before
platform = AMS::IS_PLATFORM_WINDOWS ? 'Windows' : 'another platform'
if SU2027 || AMS::IS_PLATFORM_WINDOWS
  if calls.zero?
    puts "  ok   AMS.refresh_toolbars does not call UI.refresh_toolbars (#{platform})"
  else
    failures << "AMS.refresh_toolbars called UI.refresh_toolbars #{calls} time(s) (#{platform})"
    puts "  FAIL AMS.refresh_toolbars called UI.refresh_toolbars #{calls} time(s) (#{platform})"
  end
else
  if calls == 1
    puts "  ok   AMS.refresh_toolbars refreshes the toolbars (#{platform})"
  else
    failures << "AMS.refresh_toolbars did not refresh the toolbars (#{platform})"
    puts "  FAIL AMS.refresh_toolbars did not refresh the toolbars (#{platform})"
  end
end
$checks += 1

puts
puts '== Sketchup::ShadowInfo#[]= with a read-only key =='
before = $passed_warnings.size
MSPhysics.unwritable_shadow_info_keys.clear
result = check(failures, "set_shadow_info(#{read_only_key.inspect})") {
  MSPhysics.set_shadow_info(shadow_info, read_only_key, Geom::Vector3d.new(0, 0, 1))
}
warnings = $passed_warnings.size - before
if warnings.zero?
  puts '  ok   the warning of the read-only key did not reach the Ruby console'
else
  failures << "set_shadow_info let #{warnings} warning(s) through"
  puts "  FAIL #{warnings} warning(s) reached the Ruby console"
end
$checks += 1

if SU2027
  # SketchUp 2027 warns instead of raising, so the key is learned from the
  # warning: the next attempt must not write it again.
  if MSPhysics.unwritable_shadow_info_keys.key?(read_only_key)
    puts "  ok   #{read_only_key} is remembered as unwritable"
  else
    failures << "the read-only key #{read_only_key} was not remembered"
    puts "  FAIL #{read_only_key} was not remembered as unwritable"
  end
  $checks += 1
  if MSPhysics.set_shadow_info(shadow_info, read_only_key, Geom::Vector3d.new(0, 1, 0)) == false
    puts '  ok   the remembered key is skipped'
  else
    failures << 'a key that was reported as read-only was written again'
    puts '  FAIL the remembered key was written again'
  end
  $checks += 1
else
  # SketchUp 2026.1 and 2026.2 raise a KeyError for a read-only key.
  if result == false && MSPhysics.unwritable_shadow_info_keys.key?(read_only_key)
    puts "  ok   the KeyError of #{read_only_key} is caught and remembered"
  else
    failures << "the KeyError of #{read_only_key} was not handled (#{result.inspect})"
    puts "  FAIL the KeyError of #{read_only_key} was not handled"
  end
  $checks += 1
end

check(failures, 'set_shadow_info with a writable key') {
  MSPhysics.set_shadow_info(shadow_info, 'NorthAngle', 12.5)
  shadow_info['NorthAngle']
}

puts
puts '== warnings of other code are not affected =='
before = $passed_warnings.size
Warning.warn('harness warning outside of MSPhysics')
if $passed_warnings.size - before == 1
  puts '  ok   a warning outside of without_warnings is passed through'
else
  failures << 'the extension swallowed a warning that was not its own'
  puts '  FAIL a warning outside of without_warnings was swallowed'
end
$checks += 1

before = $passed_warnings.size
MSPhysics.without_warnings { Warning.warn('harness warning inside of MSPhysics') }
if ($passed_warnings.size - before).zero?
  puts '  ok   a warning inside of without_warnings is suppressed'
else
  failures << 'without_warnings did not suppress the warning'
  puts '  FAIL without_warnings did not suppress the warning'
end
$checks += 1

if MSPhysics.warnings_suppressed?
  failures << 'warnings_suppressed? is still true after without_warnings returned'
  puts '  FAIL warnings_suppressed? is still true after the block'
else
  puts '  ok   the suppression is reset after the block'
end
$checks += 1

puts
if failures.empty?
  puts "== ALL #{$checks} SKETCHUP #{Sketchup::VERSION_MAJOR} CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
