# Harness test: compile every Ruby file of the repository with the Ruby version
# the harness runs on (3.4 for SketchUp 2027 by default, 3.2 for SketchUp
# 2024-2026 with --ruby 3.2), which is the equivalent of `ruby -c`.
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
