require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am_scheduler'
require 'dm-migrations'
require 'omf_common/load_yaml'
require 'active_support/inflector'
require 'json'

include OMF::SFA::AM

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite://~/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end

def init_logger
  OMF::Common::Loggable.init_log 'am_scheduler', :searchPath => File.join(File.dirname(__FILE__), 'am_scheduler')
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe AMScheduler do

  init_logger

  init_dm

  before do
    DataMapper.auto_migrate! # reset database
  end

  #let (:scheduler) { scheduler = AMScheduler.new() }
  scheduler = AMScheduler.new()

  describe 'instance' do
    it 'can initialize itself' do
      scheduler.must_be_instance_of(AMScheduler)
    end

    it 'can return the default account' do
      default_account = scheduler.get_nil_account()
      default_account.must_be_instance_of(OMF::SFA::Resource::Account)
    end
  end

  describe 'resources' do

    default_account = scheduler.get_nil_account()
    account = OMF::SFA::Resource::Account.create({:name => 'a1'})

    it 'can create a node' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      res.must_be_instance_of(OMF::SFA::Resource::Node)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(r)

      r1 = OMF::SFA::Resource::Node.first({:name => 'r1', :account => default_account})
      r1.must_equal(r)
      r1.provides.must_include(res)

      authorizer.verify
    end

    it 'can create a lease' do
      authorizer = MiniTest::Mock.new

      time = Time.now
      authorizer.expect(:account, account)
      lease = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => (time + 100) }, authorizer)

      lease.must_be_instance_of(OMF::SFA::Resource::Lease)
      lease.name.must_equal('l1')
      lease.account.must_equal(account)
      lease.valid_from.must_equal(time)
      lease.valid_until.must_equal(time + 100)

      authorizer.verify
    end

    it "should create a channel" do
      authorizer = MiniTest::Mock.new

      channel = OMF::SFA::Resource::Channel.create({:name => 'c1', :account => default_account})

      authorizer.expect(:account, account)
      res = scheduler.create_resource({:name => 'c1', :account => account}, 'channel', {}, authorizer)

      res.must_be_instance_of(OMF::SFA::Resource::Channel)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(channel)

      c1 = OMF::SFA::Resource::Channel.first({:name => 'c1', :account => default_account})
      c1.must_equal(channel)
      c1.provides.must_include(res)

      authorizer.verify
    end

    it 'can lease a component' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      res.must_be_instance_of(OMF::SFA::Resource::Node)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(r)

      time = Time.now
      authorizer.expect(:account, account)
      l1 = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => (time + 100)}, authorizer)
      o = scheduler.lease_component(l1, res)
    end

    it 'cannot lease components on overlapping time' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      res.must_be_instance_of(OMF::SFA::Resource::Node)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(r)

      time = Time.now
      5.times {authorizer.expect(:account, account)}
      l1 = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => (time + 100) }, authorizer)
      l2 = scheduler.create_resource({:name => 'l2'}, 'Lease', {:valid_from => time + 400, :valid_until => (time + 500)}, authorizer)
      l3 = scheduler.create_resource({:name => 'l3'}, 'Lease', {:valid_from => time + 10, :valid_until => (time + 20)}, authorizer)
      l4 = scheduler.create_resource({:name => 'l4'}, 'Lease', {:valid_from => time - 10, :valid_until => (time + 20)}, authorizer)
      l5 = scheduler.create_resource({:name => 'l5'}, 'Lease', {:valid_from => time - 410, :valid_until => (time + 490)}, authorizer)

      o1 = scheduler.lease_component(l1, res)
      o2 = scheduler.lease_component(l2, res)
      #o3 = scheduler.lease_component(l3, res)
      proc{o3 = scheduler.lease_component(l3, res)}.must_raise(UnavailableResourceException)
      proc{o4 = scheduler.lease_component(l4, res)}.must_raise(UnavailableResourceException)
    end

    it 'can release a resource' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new

      time = Time.now
      2.times{authorizer.expect(:account, account)}
      r1 = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      l1 = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => (time + 1000) }, authorizer)
      l1.status.must_equal("pending")
      scheduler.lease_component(l1, r1)

      2.times{authorizer.expect(:account, account)}
      r2 = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      l2 = scheduler.create_resource({:name => 'l2'}, 'Lease', {:valid_from => time - 1000, :valid_until => (time -100) }, authorizer)
      l2.status.must_equal("pending")
      scheduler.lease_component(l2, r2)
      l1.reload;l2.reload
      l1.status.must_equal("accepted")
      l2.status.must_equal("accepted")

      res = scheduler.release_resource(r1, authorizer)
      res.must_equal(true)
      res = scheduler.release_resource(r2, authorizer)
      res.must_equal(true)
      l1.reload;l2.reload
      l1.status.must_equal("cancelled")
      l2.status.must_equal("past")

      r.provides.must_be_empty()
    end

    it 'can release a resource without leases' do
      n = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account)

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      r1 = scheduler.create_resource({:name => 'n1'}, 'node', {}, authorizer)

      res = scheduler.release_resource(r1, authorizer)
      res.must_equal(true)
    end
  end
end
