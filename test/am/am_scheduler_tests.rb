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
  opts = {
    :mapping_submodule =>
    {
      :require => @config[:mapping_submodule][:require],
      :constructor => @config[:mapping_submodule][:constructor]
    }
  }
  scheduler = AMScheduler.new(opts)

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

    it 'can lease a component with time given as string' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      res.must_be_instance_of(OMF::SFA::Resource::Node)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(r)

      time = "2014-06-24 18:00:00 +0300"
      time2 = "2014-06-24 19:00:00 +0300"
      authorizer.expect(:account, account)
      l1 = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => time2}, authorizer)
      o = scheduler.lease_component(l1, res)

      l1.valid_until.must_be_instance_of(Time)
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

    it 'can check if a resource is available or not' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => default_account})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      time = Time.now
      authorizer.expect(:account, account)
      l1 = scheduler.create_resource({:name => 'l1'}, 'Lease', {:valid_from => time, :valid_until => (time + 100)}, authorizer)
      o = scheduler.lease_component(l1, res)

      ans = scheduler.resource_available?(r, time + 110, time + 120)
      ans.must_equal(true)
      ans = scheduler.resource_available?(r, time - 110, time - 90)
      ans.must_equal(true)
      ans = scheduler.resource_available?(r, time + 10, time + 90)
      ans.must_equal(false)
    end
  end

  describe 'unbound requests' do

    default_account = scheduler.get_nil_account()

    it 'can resolve uuid in unbound queries' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources].first[:domain].must_equal('domain1')
      ans[:resources].first[:valid_from].must_equal(t1.utc.to_s)
      ans[:resources].first[:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'can resolve uuid in unbound queries for more than one resources' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1")
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          },
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources][0][:uuid].wont_be_empty
      ans[:resources][0][:domain].must_equal('domain1')
      ans[:resources][0][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][0][:valid_until].must_equal((t1 + 7200).utc.to_s)
      ans[:resources][1][:uuid].wont_be_empty
      ans[:resources][1][:domain].must_equal('domain1')
      ans[:resources][1][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][1][:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'can resolve urn in unbound queries for more than one resources' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", urn: "domain1:n1")
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1", urn: "domain1:n2")
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          },
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources][0][:uuid].wont_be_empty
      ans[:resources][0][:urn].wont_be_empty
      ans[:resources][0][:domain].must_equal('domain1')
      ans[:resources][0][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][0][:valid_until].must_equal((t1 + 7200).utc.to_s)
      ans[:resources][1][:uuid].wont_be_empty
      ans[:resources][1][:urn].wont_be_empty
      ans[:resources][1][:domain].must_equal('domain1')
      ans[:resources][1][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][1][:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'wont give the same resource twice' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1")
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          },
          {
            type: "Node",
            domain: "domain1",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources][0][:uuid].wont_equal(ans[:resources][1][:uuid])
    end

    it 'can resolve valid_from and valid_until in unbound queries' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources].first[:domain].must_equal('domain1')
      ans[:resources].first[:valid_from].wont_be_nil
      ans[:resources].first[:valid_until].wont_be_nil
    end

    it 'can resolve valid_from and valid_until from duration in unbound queries' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            duration: 100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources].first[:domain].must_equal('domain1')
      ans[:resources].first[:valid_from].wont_be_nil
      ans[:resources].first[:valid_until].wont_be_nil
    end

    it 'can resolve exclusive in unbound queries' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            duration: 100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources].first[:domain].must_equal('domain1')
      ans[:resources].first[:exclusive].wont_be_nil
    end

    it 'can resolve exclusive in unbound queries based on already given exclusive' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", exclusive: true)
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1", exclusive: true)
      n3 = OMF::SFA::Resource::Node.create(name: 'n3', account: default_account, domain: "domain2", exclusive: false)
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            exclusive:true,
            duration:100
          },
          {
            type: "Node",
            duration:100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      7.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      # ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources][0][:domain].must_equal('domain1')
      ans[:resources][0][:exclusive].must_equal(true)
      ans[:resources][1][:domain].must_equal('domain1')
      ans[:resources][1][:exclusive].must_equal(true)
    end

    it 'can resolve domain in unbound queries' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", exclusive: true)
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1", exclusive: true)
      n3 = OMF::SFA::Resource::Node.create(name: 'n3', account: default_account, domain: "domain2", exclusive: true)
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      11.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      # ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources].first[:domain].must_equal('domain1')
      ans[:resources].first[:valid_from].must_equal(t1.utc.to_s)
      ans[:resources].first[:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'can resolve domain in unbound queries based on already given domains' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", exclusive: true)
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain1", exclusive: true)
      n3 = OMF::SFA::Resource::Node.create(name: 'n3', account: default_account, domain: "domain2", exclusive: true)
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          },
          {
            type: "Node",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      13.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      # ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources][0][:domain].must_equal('domain1')
      ans[:resources][0][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][0][:valid_until].must_equal((t1 + 7200).utc.to_s)
      ans[:resources][1][:domain].must_equal('domain1')
      ans[:resources][1][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][1][:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'can resolve both a channel and a node in the same request' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", exclusive: true)
      c1 = OMF::SFA::Resource::Channel.create(name: 'c2', account: default_account, domain: "domain1", exclusive: true)
      t1 = Time.now

      q = {
        resources:[
          {
            type: "Node",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          },
          {
            type: "Channel",
            valid_from:"#{t1}",
            valid_until:"#{t1 + 7200}"
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      13.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      ans = scheduler.resolve_query(q, manager, authorizer)

      # ans[:resources].first[:uuid].must_equal(n1.uuid.to_s)
      ans[:resources][0][:uuid].must_equal(n1.uuid.to_s)
      ans[:resources][0][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][0][:valid_until].must_equal((t1 + 7200).utc.to_s)
      ans[:resources][1][:uuid].must_equal(c1.uuid.to_s)
      ans[:resources][1][:valid_from].must_equal(t1.utc.to_s)
      ans[:resources][1][:valid_until].must_equal((t1 + 7200).utc.to_s)
    end

    it 'throws exception when there are no available resources' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain1",
            duration: 100
          },
          {
            type: "Node",
            domain: "domain1",
            duration: 100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      4.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      lambda do
        ans = scheduler.resolve_query(q, manager, authorizer)        
      end.must_raise(UnavailableResourceException)
    end

    it 'throws exception when there are no available resources matching the description' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")

      q = {
        resources:[
          {
            type: "Node",
            domain: "domain2",
            duration: 100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      2.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      lambda do
        ans = scheduler.resolve_query(q, manager, authorizer)        
      end.must_raise(UnavailableResourceException)
    end

    it 'throws exception when there are no available resources on the same domain' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1")
      n2 = OMF::SFA::Resource::Node.create(name: 'n2', account: default_account, domain: "domain2")

      q = {
        resources:[
          {
            type: "Node",
            duration: 100
          },
          {
            type: "Node",
            duration: 100
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      lambda do
        ans = scheduler.resolve_query(q, manager, authorizer)        
      end.must_raise(UnavailableResourceException)
    end

    it 'throws exception when there are no available resources with the asked exclusiveness' do
      n1 = OMF::SFA::Resource::Node.create(name: 'n1', account: default_account, domain: "domain1", exclusive: false)

      q = {
        resources:[
          {
            type: "Node",
            exclusive: true
          }
        ]
      }
      authorizer = MiniTest::Mock.new
      2.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])}
      
      manager = OMF::SFA::AM::AMManager.new(scheduler)

      lambda do
        ans = scheduler.resolve_query(q, manager, authorizer)   
        puts "answer: #{ans}"     
      end.must_raise(UnavailableResourceException)
    end
  end
end
