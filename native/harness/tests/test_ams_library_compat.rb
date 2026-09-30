# Harness test: loading MSPhysics next to an outdated AMS Library.
#
# AMS Library 3.7.1b (the latest release at the time of writing) relies on
# methods that were removed in Ruby 3, so it cannot be loaded on SketchUp 2024
# and later. MSPhysics has to fall back to the copy of AMS Library that it
# bundles (3.8.0a), which loads a pure Ruby fallback when there is no native
# build for the running Ruby version.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_ams_library_compat.rb
$stdout.sync = true

require 'sketchup.rb'
require 'fileutils'

# The bundled library and the installed one live in folders that differ only in
# case. Simulate a case sensitive file system (macOS, Linux) so that the two can
# be told apart; on Windows they are the same folder.
Object.send(:remove_const, :RUBY_PLATFORM)
RUBY_PLATFORM = 'x86_64-darwin21'.freeze

require 'MSPhysics.rb'

PLUGINS = '/.scratch/user_plugins'
EXT_DIR = File.join(PLUGINS, 'MSPhysics')

failures = []
$checks = 0

def check(failures, label)
  result = yield
  $checks += 1
  puts format('  ok   %-52s => %s', label, result.inspect[0, 50])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-52s !! %s: %s', label, err.class, err.message)
  nil
end

puts '== outgoing AMS Library next to the extension =='

# The installed library: cannot be loaded on Ruby 3, like AMS Library 3.7.1b.
FileUtils.mkdir_p(File.join(PLUGINS, 'ams_Lib'))
File.open(File.join(PLUGINS, 'ams_Lib', 'main.rb'), 'wb') { |file|
  file.write(<<-'RB'.gsub(/^    /, ''))
    module AMS
      module Lib
        VERSION = '3.7.1b'.freeze
      end
    end
    # AMS Library 3.7.1b relies on File.exists?, which Ruby 3.2 removed.
    File.exists?('dummy')
  RB
}

# The bundled library: AMS Library 3.8.0a with the Ruby fallback.
FileUtils.mkdir_p(File.join(PLUGINS, 'ams_lib'))
File.open(File.join(PLUGINS, 'ams_lib', 'main.rb'), 'wb') { |file|
  file.write(<<-'RB'.gsub(/^    /, ''))
    module AMS
      RUBY_FALLBACK_LOADED = true
      module Lib
        VERSION = '3.8.0a'.freeze
      end
    end
  RB
}

loaded = nil
problems = nil
check(failures, 'MSPhysics.load_ams_library with an outdated library') {
  loaded, problems = MSPhysics.load_ams_library(EXT_DIR)
  loaded
}
check(failures, 'the bundled AMS Library is used instead') { AMS::Lib::VERSION }
check(failures, 'the problem with the installed library is reported') { problems }
check(failures, 'AMS Library is considered usable') { MSPhysics.ams_library_usable? }

puts '== no AMS Library at all =='
check(failures, 'MSPhysics.load_ams_library without a library') {
  MSPhysics.load_ams_library('/.scratch/no_such_plugins/MSPhysics')
}

puts
if failures.empty?
  puts "== ALL #{$checks} AMS LIBRARY COMPATIBILITY CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
