# encoding: utf-8
require 'rubygems'

$:.unshift File.join(File.dirname(__FILE__), 'lib'), File.dirname(__FILE__)

require 'rake'
require 'rake/clean'

require 'rspec/core/rake_task'

desc "Run specs. Can be used as `rake spec` or `rake spec[pattern]`"
task :spec, :what do |t, args|
    what = args[:what] || ''

    RSpec::Core::RakeTask.new("rspec_#{what}") do |t|
        t.pattern = "./spec/resourrection/#{what}*.rb"
        t.rspec_opts = ["--require=./spec/spec_helpers.rb",
                      "--color",
                      "--profile",
        ]
    end
    
    Rake::Task[:"rspec_#{what}"].invoke
end
