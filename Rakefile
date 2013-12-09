
require 'rubygems'
#require 'rake/testtask'
#require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'dm-migrations'
require 'yaml'

desc 'Default: run specs.'
task :default => :spec

config = YAML.load_file(File.dirname(__FILE__) + '/etc/omf-sfa/omf-sfa-am.yaml')['omf_sfa_am']
db = config['database']

puts config

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

desc "Init database using datamapper"
task :initDB do
  options = {
    dm_log: '/tmp/am_server-dm.log',
    dm_db: "#{db['dbType']}://#{db['dbName']}"#for mysql "#{db[:dbType]}://#{db[:username]}:#{db[:password]}@#{db[:dbHostname]}/#{db[:dbName]}"
  }
  puts "options: #{options}"

  # Configure the data store
  #
  DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
  DataMapper.setup(:default, options[:dm_db])

  require 'omf-sfa/resource'
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_upgrade!
end

desc "Init database using datamapper"
task :loadTestDB do
  options = {
    dm_log: '/tmp/am_server-dm.log',
    dm_db: "#{db['dbType']}://#{db['dbName']}"#for mysql "#{db[:dbType]}://#{db[:username]}:#{db[:password]}@#{db[:dbHostname]}/#{db[:dbName]}"
  }
  puts "options: #{options}"

  # Configure the data store
  #
  DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
  DataMapper.setup(:default, options[:dm_db])

  require 'omf-sfa/resource'
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  require 'omf-sfa/resource/account'
  account = OMF::SFA::Resource::Account.create(:name => 'root')

  require 'omf-sfa/resource/link'
  require 'omf-sfa/resource/node'
  require 'omf-sfa/resource/interface'

  r = []
  lease = OMF::SFA::Resource::Lease.create(:account => account, :name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 36000)
  r << n = OMF::SFA::Resource::Node.create(:name => "node1", :urn => OMF::SFA::Resource::GURN.create("node1", :type => 'node'))
  ip1 = OMF::SFA::Resource::Ip.create(address: "10.0.0.1", netmask: "255.255.255.0", ip_type: "ipv4")
  ifr1 = OMF::SFA::Resource::Interface.create(role: "control_network", name: "node1:if0", mac: "00-03-1d-0d-4b-96", node: n, ip: ip1)
  ip2 = OMF::SFA::Resource::Ip.create(address: "10.0.0.101", netmask: "255.255.255.0", ip_type: "ipv4")
  ifr2 = OMF::SFA::Resource::Interface.create(role: "cm_network", name: "node1:if1", mac: "09:A2:DA:0D:F1:01", node: n, ip: ip2)
  n.interfaces << ifr1
  n.interfaces << ifr2
  n.leases << lease
end