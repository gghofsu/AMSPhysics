# Harness test: loading AMS Library must not delete its own Ruby files, and
# MSPhysics must be able to repair an AMS Library that is missing the fallback
# implementation.
#
# AMS::ExtensionManager#clean_up deletes every Ruby file of the library that
# was not registered with the manager. ruby_fallback.rb was not registered, so
# it was deleted from the installation of every user the first time AMS Library
# 3.8.0a was loaded. Such a library loads once and fails to load from the
# second start of SketchUp on, which is what this test reproduces and guards
# against.
#
# Run with: node native/harness/run_wasm.js native/harness/tests/test_ams_clean_up.rb
$stdout.sync = true

require 'sketchup.rb'
require 'fileutils'
require 'MSPhysics.rb'
require 'ams_lib.rb'
require 'ams_lib/main'

failures = []
$checks = 0

# Unlike the other tests, which report what they find, this one asserts: a
# check that returns false or nil is a failure.
def check(failures, label)
  result = yield
  if result.nil? || result == false
    raise "the check returned #{result.inspect}"
  end
  $checks += 1
  puts format('  ok   %-56s => %s', label, result.inspect[0, 56])
  result
rescue Exception => err
  failures << "#{label}: #{err.class}: #{err.message}"
  puts format('  FAIL %-56s !! %s: %s', label, err.class, err.message)
  nil
end

puts '== the folder of the loaded AMS Library =='
check(failures, 'AMS Library is loaded') { AMS::RUBY_FALLBACK_LOADED }
check(failures, 'ruby_fallback.rb survived the load') { File.exist?('/ams_lib/ruby_fallback.rb') }
check(failures, 'the other files of the library survived as well') {
  missing = %w[main.rb extension_manager.rb translate.rb thirdparty/fileutils.rb].reject { |name|
    File.exist?(File.join('/ams_lib', name))
  }
  missing.empty? || raise("deleted: #{missing.join(', ')}")
}

puts '== clean_up on a copy of the library =='
work = '/.scratch/ams_clean_up/ams_lib'
FileUtils.rm_rf('/.scratch/ams_clean_up')
FileUtils.mkdir_p(work)
Dir.entries('/ams_lib').each { |entry|
  next if entry =~ /\A\.\.?\z/
  source = File.join('/ams_lib', entry)
  FileUtils.cp_r(source, File.join(work, entry)) if File.file?(source)
}
# A file that is not part of the library, which clean_up has to delete.
File.open(File.join(work, 'left_over.rb'), 'wb') { |file| file.write("# left over\n") }

manager = AMS::ExtensionManager.new(work, AMS::Lib::VERSION)
manager.add_ruby_no_require('main')
manager.add_ruby_no_require('extension_manager')
manager.add_ruby_no_require('ruby_fallback')
manager.add_ruby('translate')
check(failures, 'clean_up(true) runs') { manager.clean_up(true) || 'ok' }
check(failures, 'the registered files are kept') {
  missing = %w[main.rb extension_manager.rb ruby_fallback.rb translate.rb].reject { |name|
    File.exist?(File.join(work, name))
  }
  missing.empty? || raise("deleted: #{missing.join(', ')}")
}
check(failures, 'an unregistered file is deleted') { !File.exist?(File.join(work, 'left_over.rb')) }

puts '== repairing an AMS Library that is missing ruby_fallback.rb =='
broken = '/.scratch/ams_repair/ams_Lib'
FileUtils.rm_rf('/.scratch/ams_repair')
FileUtils.mkdir_p(broken)
File.open(File.join(broken, 'main.rb'), 'wb') { |file|
  file.write(<<-'RB'.gsub(/^    /, ''))
    module AMS
      RUBY_FALLBACK_LOADED = true
      module Lib
        VERSION = '3.8.0a'.freeze
      end
    end
    # AMS Library 3.8.0a stops here when the fallback is missing.
    raise(LoadError, 'The AMS Library folder is incomplete: ruby_fallback.rb is missing!') unless File.exist?(File.join(File.dirname(__FILE__), 'ruby_fallback.rb'))
    LSPSY = true
  RB
}
check(failures, 'the copy that ships with MSPhysics exists') { File.exist?(MSPhysics.shipped_ams_fallback_path) }
check(failures, 'MSPhysics.restore_ams_fallback restores the file') {
  MSPhysics.restore_ams_fallback(broken)
}
check(failures, 'the restored file is the one that ships with MSPhysics') {
  File.binread(File.join(broken, 'ruby_fallback.rb')) == File.binread(MSPhysics.shipped_ams_fallback_path)
}
check(failures, 'the restored copy is identical to the library copy') {
  File.binread(MSPhysics.shipped_ams_fallback_path) == File.binread('/ams_lib/ruby_fallback.rb')
}
check(failures, 'load_ams_library repairs the installation') {
  loaded, problems = MSPhysics.load_ams_library('/.scratch/ams_repair/MSPhysics')
  loaded || raise(problems.inspect)
}

puts
if failures.empty?
  puts "== ALL #{$checks} AMS CLEAN UP CHECKS PASSED =="
else
  puts "== #{failures.size} of #{$checks} CHECKS FAILED =="
  failures.each { |failure| puts "   - #{failure}" }
  raise 'HARNESS TESTS FAILED'
end
