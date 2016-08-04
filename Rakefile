require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/*_tests.rb"
end

namespace :test do
  task :classic do
    ENV['app_type'] = 'classic'
    puts "\nTesting for classic style apps...\n\n"
    puts %x{rake test}
  end

  task :modular do
    ENV['app_type'] = 'modular'
    puts "\nTesting for modular style apps...\n\n"
    puts %x{rake test}
  end

  task :all do
    Rake::Task['test:classic'].execute
    Rake::Task['test:modular'].execute
  end
end
