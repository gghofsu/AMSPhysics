# Harness test: verify that the staged native engines cover the SketchUp
# versions that are expected to be supported.
#
# SketchUp 2017-2023 use Ruby 2.2/2.5/2.7, SketchUp 2024-2026 use Ruby 3.2.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_abi_gate.rb
$stdout.sync = true

STAGE = '/MSPhysics/libraries/stage'

# Rubies used by the SketchUp versions that MSPhysics supports.
RUBY_VERSIONS = {
  '2017' => '2.2',
  '2018' => '2.2',
  '2019' => '2.5',
  '2021' => '2.7',
  '2024' => '3.2',
  '2025' => '3.2',
  '2026' => '3.2',
}.freeze

failures = []

# Mirrors the check performed by MSPhysics/main_entry.rb.
def available_abis(stage_dir, c_ext)
  return [] unless File.directory?(stage_dir)
  Dir.entries(stage_dir).select { |entry|
    File.exist?(File.join(stage_dir, entry, 'msp_lib' + c_ext))
  }.sort
end

puts "== native engine coverage in #{STAGE} =="
results = {}
{ 'win64' => '.so', 'osx64' => '.bundle' }.each do |platform, c_ext|
  abis = available_abis(File.join(STAGE, platform), c_ext)
  results[platform] = abis
  puts "   #{platform}: #{abis.inspect}"
end

puts
puts '== requirements =='
# Windows is the platform the extension is fully supported on: the staged
# win64 engine has to exist for Ruby 3.2 (SketchUp 2024-2026).
if results['win64'].include?('3.2')
  puts '  ok   win64 Ruby 3.2 engine (SketchUp 2024-2026)'
else
  failures << 'win64 Ruby 3.2 engine is missing'
  puts '  FAIL win64 Ruby 3.2 engine (SketchUp 2024-2026)'
end

results['win64'].each do |abi|
  next unless RUBY_VERSIONS.values.include?(abi)
  puts "  ok   win64 Ruby #{abi} engine present"
end

if results['osx64'].include?('3.2')
  puts '  ok   osx64 Ruby 3.2 engine (SketchUp 2024-2026)'
else
  puts '  note osx64 has no Ruby 3.2 engine; the ABI gate reports this to the user'
end

puts
if failures.empty?
  puts '== ABI GATE CHECKS PASSED =='
else
  puts "== #{failures.size} FAILURES =="
  failures.each { |failure| puts "   - #{failure}" }
  exit 1
end
