# Sample for native/harness/tests/test_chilled_strings.rb.
#
# This file deliberately mutates string literals in the two ways that occur in
# extension code. Ruby 3.4 compiles the literals of a file without a
# frozen_string_literal comment into chilled strings and reports their
# mutation as a deprecation warning; a future Ruby version is to freeze them.
# The test compiles this file and has to report both mutations, which is what
# shows that the check is not vacuous.
#
# The file is never executed; it is only compiled.

def chilled_string_sample_accumulator
  cmd = ''
  cmd << 'statement;'
  cmd
end

def chilled_string_sample_direct
  ''.concat('statement;')
end
