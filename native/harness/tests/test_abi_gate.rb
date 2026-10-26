# Harness test: verify that the staged native engines cover the SketchUp
# versions that are expected to be supported.
#
# SketchUp 2017-2023 use Ruby 2.2/2.5/2.7, SketchUp 2024-2026 use Ruby 3.2 and
# SketchUp 2027 uses Ruby 3.4.
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
  '2027' => '3.4',
}.freeze

# The Ruby versions for which a Windows engine has to be staged: Ruby 3.2 for
# SketchUp 2024-2026 and Ruby 3.4 for SketchUp 2027.
REQUIRED_WIN64_ABIS = ['3.2', '3.4'].freeze

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
# Windows is the platform the extension is fully supported on: a staged win64
# engine has to exist for every Ruby version of a supported SketchUp release
# that is still current (Ruby 3.2 and Ruby 3.4).
REQUIRED_WIN64_ABIS.each do |abi|
  releases = RUBY_VERSIONS.select { |_release, version| version == abi }.keys
  if results['win64'].include?(abi)
    puts "  ok   win64 Ruby #{abi} engine (SketchUp #{releases.join(', ')})"
  else
    failures << "win64 Ruby #{abi} engine is missing (SketchUp #{releases.join(', ')})"
    puts "  FAIL win64 Ruby #{abi} engine is missing (SketchUp #{releases.join(', ')})"
  end
end

results['win64'].each do |abi|
  next unless RUBY_VERSIONS.values.include?(abi)
  puts "  ok   win64 Ruby #{abi} engine present"
end

# Both msp_lib and newton.dll are built from the same sources and have to be
# shipped as a pair, per Ruby ABI version. (The older ABI folders only ship
# msp_lib; they use the generic newton.dll of the stage folder.)
REQUIRED_WIN64_ABIS.each do |abi|
  next unless results['win64'].include?(abi)
  dir = File.join(STAGE, 'win64', abi)
  missing = %w[msp_lib.so newton.dll].reject { |name| File.exist?(File.join(dir, name)) }
  if missing.empty?
    puts "  ok   win64/#{abi} ships msp_lib.so and newton.dll"
  else
    failures << "win64/#{abi} is missing #{missing.join(', ')}"
    puts "  FAIL win64/#{abi} is missing #{missing.join(', ')}"
  end
end

['3.2', '3.4'].each do |abi|
  if results['osx64'].include?(abi)
    puts "  ok   osx64 Ruby #{abi} engine present"
  else
    puts "  note osx64 has no Ruby #{abi} engine; the ABI gate reports this to the user"
  end
end

puts
if failures.empty?
  puts '== ABI GATE CHECKS PASSED =='
else
  puts "== #{failures.size} FAILURES =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
