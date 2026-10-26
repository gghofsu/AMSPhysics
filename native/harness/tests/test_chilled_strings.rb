# Harness test: no string literal of the extension is mutated.
#
# Ruby 3.4 - the Ruby version SketchUp 2027 embeds - compiles the string
# literals of a file that has no frozen_string_literal comment into "chilled"
# strings: mutating one still works, but emits a deprecation warning, and a
# future Ruby version is to freeze them, which would turn every such mutation
# into a FrozenError. Mutating a literal is written as an accumulator:
#
#   cmd = ''
#   cmd << "..."
#
# which is how the panels and the dialogs of MSPhysics assemble their
# JavaScript, and how the replay writer assembles its data files. Such an
# accumulator has to start with String.new instead of a literal.
#
# Two independent checks are performed:
#
#   1. every Ruby file of the extension is compiled and its instructions are
#      followed with a simulation of the operand stack: a chilled string that
#      is the receiver of a call that mutates it in place is reported. This
#      covers every file, also the ones that need a SketchUp installation to
#      be run.
#   2. the code paths that assemble JavaScript are run with the deprecation
#      warnings turned on, and no warning may come from the extension.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_chilled_strings.rb
$stdout.sync = true

require 'sketchup.rb'

# Turn the deprecation warnings on before anything else is loaded: they are
# only emitted when they are enabled.
Warning[:deprecated] = true if Warning.respond_to?(:[]=)

$runtime_warnings = []
if defined?(::Warning)
  # A singleton method of Warning itself is called after every module that was
  # prepended to it, so this sees every warning of the run.
  ::Warning.define_singleton_method(:warn) do |*args, **kwargs|
    $runtime_warnings << args.first.to_s
    nil
  end
end

require 'MSPhysics.rb'

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

# The String methods that mutate their receiver in place.
MUTATING_METHODS = %i[
  concat prepend insert replace clear force_encoding
  gsub! sub! upcase! downcase! capitalize! swapcase!
  strip! lstrip! rstrip! chomp! chop! squeeze! tr! delete! setbyte
].freeze

# VM_CALL_ARGS_BLOCKARG_BIT: a block is passed as an argument.
ARGS_BLOCKARG = 0x08
# VM_CALL_ARGS_SPLAT_BIT: the arguments are expanded from an array, which
# means that the number of stack entries cannot be taken from orig_argc.
ARGS_SPLAT = 0x02

# The instructions that push exactly one value without consuming anything.
PUSH_ONE = %i[
  putnil putself putstring putobject putobject_INT2FIX_0_ putobject_INT2FIX_1_
  putspecialvalue putiseq once opt_getconstant_path getglobal
  getinstancevariable getclassvariable getconstant getblockparam
  getblockparamproxy putchilledstring
].freeze

# Follow the instructions of an instruction sequence with a simulation of the
# operand stack and report the calls that mutate a chilled string. The strings
# of an interpolation and the strings created with String.new are not chilled,
# so they are not reported.
#
# The stack is dropped whenever an instruction is reached that this simulation
# does not follow, so a report is always based on the instructions that were
# actually followed, and code that cannot be followed is simply not reported.
# @param [RubyVM::InstructionSequence] iseq
# @return [Array<String>] descriptions of the mutations that were found
def chilled_mutations(iseq)
  found = []
  chilled_slots = {}
  stack = []
  line = 0

  iseq.to_a.last.each do |instruction|
    unless instruction.is_a?(Array)
      line = instruction if instruction.is_a?(Integer)
      next
    end
    name = instruction[0]

    if name == :putchilledstring
      stack.push(:chilled)
    elsif PUSH_ONE.include?(name)
      stack.push(:value)
    elsif name.to_s.start_with?('setlocal')
      chilled_slots[instruction[-1]] = (stack.pop == :chilled)
    elsif name.to_s.start_with?('getlocal')
      stack.push(chilled_slots[instruction[-1]] ? :chilled : :value)
    elsif name == :dup
      stack.push(stack.last || :value)
    elsif name == :pop
      stack.pop
    elsif name == :concatstrings || name == :newhash || name == :newarray ||
          name == :newarraykwsplat || name == :newhashkwsplat
      count = instruction[1].to_i
      count.times { stack.pop }
      stack.push(:value)
    elsif name == :tostring || name == :objtostring || name == :opt_length ||
          name == :opt_size || name == :opt_empty_p || name == :opt_succ ||
          name == :opt_not || name == :newhashfromarray || name == :expandarray
      stack.pop
      stack.push(:value)
    elsif name == :anytostring
      stack.pop
      stack.pop
      stack.push(:value)
    elsif name == :opt_ltlt
      # receiver << argument
      stack.pop
      found << "#{iseq.label} (line #{line}): <<" if stack.pop == :chilled
      stack.push(:value)
    elsif name == :opt_send_without_block || name == :send
      argc = instruction[1].is_a?(Hash) ? instruction[1][:orig_argc].to_i : 0
      argc += 1 if instruction[1].is_a?(Hash) && (instruction[1][:flag].to_i & ARGS_BLOCKARG) != 0
      argc.times { stack.pop }
      # A splat is expanded on the fly; the simulation cannot follow it.
      next if instruction[1].is_a?(Hash) && (instruction[1][:flag].to_i & ARGS_SPLAT) != 0
      receiver = stack.pop
      mid = instruction[1].is_a?(Hash) ? instruction[1][:mid] : nil
      if receiver == :chilled && MUTATING_METHODS.include?(mid)
        found << "#{iseq.label} (line #{line}): #{mid}"
      end
      stack.push(:value)
    elsif name == :opt_aref || name == :opt_aref_with || name == :opt_plus ||
          name == :opt_minus || name == :opt_mult || name == :opt_div ||
          name == :opt_mod || name == :opt_eq || name == :opt_neq ||
          name == :opt_lt || name == :opt_le || name == :opt_gt ||
          name == :opt_ge || name == :opt_regexpmatch2 || name == :checkmatch ||
          name == :invokesuper || name == :invokeblock
      argc = instruction[1].is_a?(Hash) ? instruction[1][:orig_argc].to_i : 1
      argc.times { stack.pop }
      stack.pop
      stack.push(:value)
    elsif name == :nop || name == :leave
      # The stack does not change.
    else
      # Jumps, branches and the instructions that are not followed here make
      # the stack unknowable.
      stack = []
    end
  end
  found.uniq
end

def scan_file(path)
  iseq = RubyVM::InstructionSequence.compile(File.read(path), path)
  found = []
  walk = lambda do |current|
    found.concat(chilled_mutations(current).map { |item| "#{path}: #{item}" })
    current.each_child { |child| walk.call(child) }
  end
  walk.call(iseq)
  found
rescue Exception => err
  ["#{path}: could not be compiled (#{err.class}: #{err.message})"]
end

puts '== environment =='
puts "   Ruby #{RUBY_VERSION}, SketchUp #{Sketchup::VERSION} (simulated)"
puts "   deprecation warnings: #{Warning.respond_to?(:[]) ? Warning[:deprecated].inspect : 'n/a'}"

# Ruby compiles the literals of a file without a frozen_string_literal comment
# into chilled strings from 3.4 on, which is the Ruby version of SketchUp 2027.
# On an older Ruby the walk finds nothing, which says nothing about the code.
CHILLED_LITERALS = (RUBY_VERSION.split('.').first(2).map(&:to_i) <=> [3, 4]) >= 0

puts
puts '== the check detects a mutated literal =='
offenders = scan_file('/native/harness/tests/fixtures/chilled_string_sample.rb')
puts "   sample: #{offenders.inspect}"
if !CHILLED_LITERALS
  puts "  ok   Ruby #{RUBY_VERSION} does not chill literals; the sample does not apply"
elsif offenders.size == 2
  puts '  ok   both mutated literals of the sample are reported'
else
  failures << "the instruction walk reported #{offenders.size} of the 2 mutated literals of the sample"
  puts '  FAIL the instruction walk did not report both mutations of the sample'
end
$checks += 1

puts
puts '== instruction walk over the Ruby files of the extension =='
files = Dir.glob('/{MSPhysics,ams_lib}/**/*.rb').sort
puts "   #{files.size} files#{CHILLED_LITERALS ? '' : " (Ruby #{RUBY_VERSION} does not chill literals; this walk reports nothing here)"}"
offenders = files.flat_map { |path| scan_file(path) }
if offenders.empty?
  puts "  ok   no literal is mutated in the #{files.size} Ruby files"
else
  failures.concat(offenders)
  offenders.each { |offender| puts "  FAIL #{offender}" }
end
$checks += 1

puts
puts '== the panels and the dialogs assemble their JavaScript =='
# Every one of these methods starts with an empty string and appends the
# statements of the panel to it.
dialog_methods = %w[
  update_simulation_state
  update_simulation_sliders
  update_body_state
  update_joint_state
  update_sound_state
].select { |name| MSPhysics::Dialog.respond_to?(name) }

dialog_methods.each do |name|
  check(failures, "MSPhysics::Dialog.#{name}") {
    MSPhysics::Dialog.send(name)
    :ok
  }
end

puts
puts '== no deprecation warning came from the extension =='
offenders = $runtime_warnings.grep(/will be frozen in the future/).grep(%r{\A/(MSPhysics|ams_lib)/})
offenders.each { |warning| puts "   #{warning.strip}" }
if offenders.empty?
  puts '  ok   no deprecation warning from the Ruby files of the extension'
else
  failures.concat(offenders.map { |warning| "mutated literal: #{warning.strip}" })
end
$checks += 1

puts
if failures.empty?
  puts "== ALL #{$checks} CHILLED STRING CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
