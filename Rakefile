require 'rubygems'
#require 'rake/testtask'
#require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'yaml'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'

desc 'Default: run specs.'
task :default => :spec

config = YAML.load_file(File.dirname(__FILE__) + '/etc/omf-sfa/omf-sfa-am.yaml')['omf_sfa_am']
db = config['database']

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  t.pattern = "./spec/am/*_spec.rb"
  t.verbose = true
  # Put spec opts in a file named .rspec in root
end

desc "Generate code coverage"
RSpec::Core::RakeTask.new(:coverage) do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

namespace :db do
  desc "Run migrations ('rake db:migrate' to run all migrations, 'rake db:migrate[10]'' to run the 10th migration, 'rake db:migrate[0] to reset the db)"
  task :migrate, [:version] do |t, args|
    desc "Migrate the db"
    require "sequel"
    Sequel.extension :migration
    db = Sequel.connect(db)
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, "migrations", target: args[:version].to_i)
      puts "done!"
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(db, "migrations")
      puts "done!"
    end
  end
  task :reset do |t|
    desc "Migrate the db"
    require "sequel"
    Sequel.extension :migration
    db = Sequel.connect(db)
    puts "Reseting the database"
    Sequel::Migrator.run(db, "migrations", target: 0)
    puts "done!"
  end
end
