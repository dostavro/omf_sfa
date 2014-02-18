require 'rubygems'
#require 'rake/testtask'
#require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'dm-migrations'
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

desc "Init database using datamapper"
task :initDB do
  @am_manager = nil

  db_desc = db['dbType'] == 'sqlite' ? "#{db['dbType']}://#{db['dbName']}" : "#{db[:dbType]}://#{db[:username]}:#{db[:password]}@#{db[:dbHostname]}/#{db[:dbName]}"
  options = {
    dm_log: '/tmp/am_server-dm.log',
    dm_db: "#{db_desc}"
  }
  # Configure the data store
  #
  puts "Creating database #{options[:dm_db]}"
  DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
  DataMapper.setup(:default, options[:dm_db])

  require 'omf-sfa/resource'
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  puts "Database is created."
end

desc "Datamapper's Auto upgrade."
task :autoUpgrade => [:initDB] do
  puts "Auto upgrade started"
  DataMapper.auto_upgrade!
  puts "Auto upgrade completed"
end

desc "Datamapper's Auto migrade."
task :autoMigrate => [:initDB] do
  puts "Auto migrate started"
  DataMapper.auto_migrate!
  puts "Auto migrate completed"
end

desc "Init database using datamapper"
task :loadTestDB => [:autoMigrate] do
  puts "Loading test data to db."
  @am_manager = OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new)
  if @am_manager.is_a? Proc
    @am_manager = @am_manager.call
  end
  require 'omf-sfa/resource/account'
  r = []
  r << account = OMF::SFA::Resource::Account.create(:name => 'root')
  lease = OMF::SFA::Resource::Lease.create(:account => account, :name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 36000)
#   r << n = OMF::SFA::Resource::Node.create(:name => "node1", :urn => OMF::SFA::Resource::GURN.create("node1", :type => 'node'), :hostname => "node1")
#   r << ip1 = OMF::SFA::Resource::Ip.create(address: "10.0.1.1", netmask: "255.255.255.0", ip_type: "ipv4")
#   r << ifr1 = OMF::SFA::Resource::Interface.create(role: "control", name: "node1:if0", mac: "00-03-1d-0d-4b-96", node: n, ip: ip1)
#   r << ifr2 = OMF::SFA::Resource::Interface.create(role: "experimental", name: "node1:if1", mac: "00-03-1d-0d-4b-97", node: n)
#   r << ip2 = OMF::SFA::Resource::Ip.create(address: "10.0.0.101", netmask: "255.255.255.0", ip_type: "ipv4")
#   r << cmc = OMF::SFA::Resource::ChasisManagerCard.create(name: "node1:cm", mac: "09:A2:DA:0D:F1:01", node: n, ip: ip2)
  r << n1 = OMF::SFA::Resource::Node.create(:name => "node120", :urn => OMF::SFA::Resource::GURN.create("node120", :type => 'node'), :hostname => "node120")
  r << ip1 = OMF::SFA::Resource::Ip.create(address: "10.0.1.120", netmask: "255.255.255.0", ip_type: "ipv4")
  r << ifr1 = OMF::SFA::Resource::Interface.create(role: "control", name: "node120:if0", mac: "00-03-1d-0d-4b-96", node: n1, ip: ip1)
  r << ifr2 = OMF::SFA::Resource::Interface.create(role: "experimental", name: "node120:if1", mac: "00-03-1d-0d-4b-97", node: n1)
  r << ip2 = OMF::SFA::Resource::Ip.create(address: "10.1.0.120", netmask: "255.255.255.0", ip_type: "ipv4")
  r << cmc = OMF::SFA::Resource::ChasisManagerCard.create(name: "node120:cm", mac: "09:A2:DA:0D:F1:20", node: n1, ip: ip2)
  n1.interfaces << ifr1
  n1.interfaces << ifr2
  n1.cmc = cmc
  n1.leases << lease

  r << n2 = OMF::SFA::Resource::Node.create(:name => "node121", :urn => OMF::SFA::Resource::GURN.create("node121", :type => 'node'), :hostname => "node121")
  r << ip3 = OMF::SFA::Resource::Ip.create(address: "10.0.1.121", netmask: "255.255.255.0", ip_type: "ipv4")
  r << ifr3 = OMF::SFA::Resource::Interface.create(role: "control", name: "node121:if0", mac: "00-03-1d-0d-40-98", node: n2, ip: ip3)
  r << ifr4 = OMF::SFA::Resource::Interface.create(role: "experimental", name: "node120:if1", mac: "00-03-1d-0d-40-99", node: n2)
  r << ip4 = OMF::SFA::Resource::Ip.create(address: "10.1.0.121", netmask: "255.255.255.0", ip_type: "ipv4")
  r << cmc2 = OMF::SFA::Resource::ChasisManagerCard.create(name: "node121:cm", mac: "09:A2:DA:0D:F1:21", node: n2, ip: ip4)
  n2.interfaces << ifr3
  n2.interfaces << ifr4
  n2.cmc = cmc2
  n2.leases << lease
  n2.save

  @am_manager.manage_resources(r)
  puts "Loading done."
end