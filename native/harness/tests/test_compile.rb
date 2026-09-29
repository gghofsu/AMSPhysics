# Harness test: compile every Ruby file of the repository with the embedded
# CRuby 3.2 (the Ruby version used by SketchUp 2024-2026), which is the
# equivalent of `ruby -c`.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_compile.rb
$stdout.sync = true

files = Dir.glob('/**/*.rb').sort
bad = 0
files.each do |fpath|
  src = File.read(fpath)
  begin
    RubyVM::InstructionSequence.compile(src, fpath, fpath, 1)
  rescue SyntaxError => err
    bad += 1
    puts "SYNTAX ERROR in #{fpath}"
    puts "  #{err.message.lines.first(4).join('  ')}"
  end
end
puts '---'
puts "#{files.size} files checked with Ruby #{RUBY_VERSION}, #{bad} with syntax errors"
raise 'HARNESS TESTS FAILED' unless bad.zero?
