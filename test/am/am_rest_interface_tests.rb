require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/am/am_manager'
require 'dm-migrations'
require 'omf_common/load_yaml'
require 'active_support/inflector'
require 'json'

include OMF::SFA::AM::Rest

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  # DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end

def init_logger
  OMF::Common::Loggable.init_log 'am_rest', :searchPath => File.join(File.dirname(__FILE__), 'am_rest')
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe ResourceHandler do

  init_logger

  init_dm

  scheduler = nil
  manager = nil
  rest = nil

  before do
    DataMapper.auto_migrate! # reset database
    scheduler = OMF::SFA::AM::AMScheduler.new
    manager = OMF::SFA::AM::AMManager.new(scheduler)
    rest = ResourceHandler.new(manager)
  end

  # let (:scheduler) do
  #   scheduler = Class.new do
  #     def self.get_nil_account
  #       nil
  #     end
  #     def self.create_resource(resource_descr, type_to_create, oproperties, auth)
  #       puts "create_resource: resource_descr:'#{resource_descr}' type_to_create:'#{type_to_create}' oproperties:'#{oproperties}' authorizer:'#{auth.inspect}'"
  #       resource_descr[:resource_type] = type_to_create
  #       resource_descr[:account] = auth.account
  #       type = type_to_create.camelize
  #       resource = eval("OMF::SFA::Resource::#{type}").create(resource_descr)
  #       if type_to_create.eql?('Lease')
  #         resource.valid_from = oproperties[:valid_from]
  #         resource.valid_until = oproperties[:valid_until]
  #         resource.save
  #       end
  #       resource
  #     end
  #     def self.release_resource(resource, authorizer)
  #       resource.destroy
  #     end
  #     def self.lease_component(lease, resource)
  #       resource.leases << lease
  #       resource.save
  #     end
  #   end
  #   scheduler
  # end

  # let (:scheduler) { OMF::SFA::AM::AMScheduler.new}
  # let (:manager){ OMF::SFA::AM::AMManager.new(scheduler)}
  # let (:rest){ResourceHandler.new(manager)}
  

  describe 'instance' do
    it 'can initialize itself' do
      rest.must_be_instance_of(ResourceHandler)
    end
  end

  describe 'resources' do
    it 'can list resources' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})

      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      4.times {opts[:req].expect(:path, "/resources/nodes")}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_view_resource?, true, [Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_get('nodes', opts)
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      nodes = JSON.parse(json)["resource_response"]["resources"]
      nodes.must_be_instance_of(Array)
      node = nodes.first
      node["name"].must_equal("r1")

      opts[:req].verify
      authorizer.verify
    end

    it 'can create a new resource' do 
      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/channels")}
      opts[:req].expect(:body, "{  \"name\":\"1\",  \"frequency\":\"2.412GHz\"}")
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_create_resource?, true, [Object, Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_post('channels', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      channel = JSON.parse(json)["resource_response"]["resource"]
      channel.must_be_instance_of(Hash)
      channel["name"].must_equal("1")

      # check if it is in the db
      c = OMF::SFA::Resource::Channel.first
      c.must_be_instance_of(OMF::SFA::Resource::Channel)
      c.name.must_equal('1')
      c.frequency.must_equal('2.412GHz')

      opts[:req].verify
      authorizer.verify
    end

    it 'can update a resource' do 
      c = OMF::SFA::Resource::Channel.create({:name => '1', :frequency => '2.412GHz'})
      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/channels")}
      opts[:req].expect(:body, "{  \"uuid\":\"#{c.uuid}\",  \"frequency\":\"2.416GHz\"}")
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_modify_resource?, true, [Object, Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_put('channels', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      channel = JSON.parse(json)["resource_response"]["resource"]
      channel.must_be_instance_of(Hash)
      channel["frequency"].must_equal("2.416GHz")

      # check if it is in the db
      c = OMF::SFA::Resource::Channel.first
      c.must_be_instance_of(OMF::SFA::Resource::Channel)
      c.name.must_equal('1')
      c.frequency.must_equal('2.416GHz')

      opts[:req].verify
      authorizer.verify
    end

    it 'can delete a resource' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})
      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/nodes")}
      opts[:req].expect(:body, "{  \"uuid\":\"#{r.uuid}\" }")
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_release_resource?, true, [Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_delete('nodes', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)
      resp = JSON.parse(json)["resource_response"]["response"]
      resp.must_equal('OK')

      # check if it is in the db
      r = OMF::SFA::Resource::Node.first
      r.must_equal(nil)

      opts[:req].verify
      authorizer.verify
    end
  end 

  describe 'leases' do
    it 'can list leases' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})
      a = OMF::SFA::Resource::Account.create(:name => 'root')
      time1 = Time.now
      time2 = Time.now + 36000
      l = OMF::SFA::Resource::Lease.create(:account => a, :name => 'l1', :valid_from => time1, :valid_until => time2)
      r.leases << l
      r.save
  
      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      4.times {opts[:req].expect(:path, "/resources/leases")}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_view_resource?, true, [Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_get('leases', opts)
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      leases = JSON.parse(json)["resource_response"]["resources"]
      leases.must_be_instance_of(Array)
      lease = leases.first
      lease["name"].must_equal("l1")

      opts[:req].verify
      authorizer.verify
    end

    it 'can create a new lease' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})
      manager.manage_resource(r)
      a = OMF::SFA::Resource::Account.create(:name => 'account1')
      time1 = "2014-06-24 18:00:00 +0300"
      time2 = "2014-06-24 19:00:00 +0300"

      l_json = "{ \"name\": \"l1\", \"valid_from\": \"#{time1}\", \"valid_until\": \"#{time2}\", \"account\":{\"name\": \"account1\"}, \"components\":[{\"name\": \"r1\"}]}"

      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/leases")}
      opts[:req].expect(:body, l_json)
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_create_resource?, true, [Object, Object])
      authorizer.expect(:account=, nil, [a])
      2.times {authorizer.expect(:account, a)}
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_post('leases', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      lease = JSON.parse(json)["resource_response"]["resource"]
      lease.must_be_instance_of(Hash)
      lease["name"].must_equal("l1")
      lease["account"]["name"].must_equal("account1")
      
      # check if it is in the db
      l = OMF::SFA::Resource::Lease.first
      l.name.must_equal("l1")
      l.components.first.name.must_equal("r1")
      l.valid_from.must_be_instance_of(Time)
      l.valid_from.to_s.must_equal(time1)
      l.valid_until.must_be_instance_of(Time)
      l.valid_until.to_s.must_equal(time2)

      opts[:req].verify
      authorizer.verify
    end

    it 'can update a lease' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})
      manager.manage_resource(r)
      a = OMF::SFA::Resource::Account.create(:name => 'account1')
      t1 = Time.now
      t2 = (t1 + 100)
      l = OMF::SFA::Resource::Lease.create(name: 'l1', valid_from: t1, valid_until: t2, account: a, components: [r])
      l_json = "{ \"uuid\": \"#{l.uuid}\", \"valid_from\": \"#{t1 + 50}\" }"

      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/leases")}
      opts[:req].expect(:body, l_json)
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_modify_resource?, true, [Object, Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_put('leases', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)

      lease = JSON.parse(json)["resource_response"]["resource"]
      lease.must_be_instance_of(Hash)
      lease["name"].must_equal("l1")
      t3 = Time.parse(lease["valid_from"])
      t4 = (t1 + 50)
      t3.to_i.must_equal(t4.to_i)

      
      # check if it is in the db
      l = OMF::SFA::Resource::Lease.first
      l.name.must_equal("l1")
      l.valid_from.must_be_instance_of(Time)
      l.valid_from.to_i.must_equal(t4.to_i)
      l.valid_until.must_be_instance_of(Time)
      l.valid_until.to_i.must_equal(t2.to_i)

      opts[:req].verify
      authorizer.verify
    end

    it 'can delete a lease' do 
      r = OMF::SFA::Resource::Node.create({:name => 'r1'})
      manager.manage_resource(r)
      a = OMF::SFA::Resource::Account.create(:name => 'account1')
      t1 = Time.now
      t2 = (t1 + 100)
      l = OMF::SFA::Resource::Lease.create(name: 'l1', valid_from: t1, valid_until: t2, account: a, components: [r])

      opts = {}
      opts[:req] = MiniTest::Mock.new
      opts[:req].expect(:params, {})
      2.times {opts[:req].expect(:path, "/resources/leases")}
      opts[:req].expect(:body, "{ \"uuid\": \"#{l.uuid}\" }")
      2.times {opts[:req].expect(:content_type, 'application/json')}

      authorizer = MiniTest::Mock.new
      authorizer.expect(:can_release_lease?, true, [Object])
      authorizer.expect(:can_release_resource?, true, [Object])
      Thread.current["authenticator"] = authorizer

      type, json = rest.on_delete('leases', opts)
      
      type.must_be_instance_of(String)
      type.must_equal("application/json")
      json.must_be_instance_of(String)
      resp = JSON.parse(json)["resource_response"]["response"]
      resp.must_equal('OK')

      # check if it is in the db
      lease = OMF::SFA::Resource::Lease.first
      lease.components.must_equal([])
      lease.status.must_equal('cancelled')

      opts[:req].verify
      authorizer.verify
    end
  end 
end