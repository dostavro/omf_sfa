require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'
require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf_common/load_yaml'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

OMF::Common::Loggable.init_log('am_manager', { :searchPath => File.join(File.dirname(__FILE__), 'am_manager') })
::Log4r::Logger.global.level = ::Log4r::OFF

# Must use this class as the base class for your tests
class AMRestInterface < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def before_setup
    @scheduler = OMF::SFA::AM::AMScheduler.new
    @manager = OMF::SFA::AM::AMManager.new(@scheduler)
    @rest = OMF::SFA::AM::Rest::ResourceHandler.new(@manager)
  end

  #resource related tests
  def test_it_can_initialize_itself
    assert_instance_of OMF::SFA::AM::Rest::ResourceHandler, @rest
  end

  def test_it_can_list_all_resources
    r1 = OMF::SFA::Model::Node.create({:name => 'r1', :account => @scheduler.get_nil_account})
    r2 = OMF::SFA::Model::Node.create({:name => 'r2', :account => @scheduler.get_nil_account})

    authorizer = MiniTest::Mock.new
    6.times {authorizer.expect(:can_view_resource?, true, [Object])}
    opts = {}
    opts[:req] = MiniTest::Mock.new
    # opts[:req].expect(:params, [])
    2.times {opts[:req].expect(:session, {authorizer: authorizer})}
    8.times {opts[:req].expect(:path, "/resources")}
    4.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources"})}
    1.times {opts[:req].expect(:body, '{}')}
    2.times {opts[:req].expect(:content_type, 'application/json')}
    opts[:account] = @scheduler.get_nil_account

    type, json = @rest.on_get('', opts)

    nodes = JSON.parse(json)["resource_response"]["resources"]
    assert_instance_of Array, nodes
    node = nodes.first
    assert_equal node["name"],"r1"
    assert_equal nodes.size, 2

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_list_resources
    r = OMF::SFA::Model::Node.create({:name => 'r1', :account => @scheduler.get_nil_account})

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_view_resource?, true, [Object])
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:session, {authorizer: authorizer})}
    4.times {opts[:req].expect(:path, "/resources/nodes")}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    type, json = @rest.on_get('nodes', opts)

    nodes = JSON.parse(json)["resource_response"]["resources"]
    assert_instance_of Array, nodes
    node = nodes.first
    assert_equal node["name"],"r1"

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_list_accounts_based_on_user_param
    a = OMF::SFA::Model::Account.create({:name => 'a1'})
    u = OMF::SFA::Model::User.create({:name => 'u1', :account => a})

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {user: "u1"})
    4.times {opts[:req].expect(:path, "/resources/accounts")}

    authorizer = MiniTest::Mock.new
    # 5.times {authorizer.expect(:can_view_resource?, true, [Object])}
    1.times {authorizer.expect(:user, "u1")}
    2.times {authorizer.expect(:can_view_account?, true, [OMF::SFA::Model::Account])}
    2.times {opts[:req].expect(:session, {authorizer: authorizer})}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources"})}

    type, json = @rest.on_get('accounts', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    accounts = JSON.parse(json)["resource_response"]["resources"]
    assert_instance_of Array, accounts
    account = accounts.first
    assert_equal account["name"], "a1"

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_a_new_resource 
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/channels")}
    opts[:req].expect(:body, "{  \"name\":\"1\",  \"frequency\":\"2.412GHz\"}")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_create_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('channels', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    channel = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, channel
    assert_equal channel["name"], "1"

    # check if it is in the db
    c = OMF::SFA::Model::Channel.first
    assert_instance_of OMF::SFA::Model::Channel, c
    assert_equal c.name, '1'
    assert_equal c.frequency, '2.412GHz'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_a_new_resource_which_contains_a_complex_Hash_resource
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/nodes")}
    opts[:req].expect(:body, "{\"name\":\"n1\",\"cpus_attributes\":[{\"name\":\"cpu1\"}]}")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_create_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('nodes', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    nodes = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, nodes
    assert_equal nodes["name"], "n1"

    # check if it is in the db
    n = OMF::SFA::Model::Node.first
    assert_instance_of OMF::SFA::Model::Node, n
    assert_equal n.name, 'n1'
    assert_equal n.cpus.first.name, 'cpu1'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_a_new_resource_which_contains_a_complex_Array_resource
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/nodes")}
    opts[:req].expect(:body, "{\"name\":\"n1\",\"interfaces_attributes\":[{\"name\":\"n1:if0\"}]}")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_create_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('nodes', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    node = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, node
    assert_equal node["name"], "n1"

    # # check if it is in the db
    n = OMF::SFA::Model::Node.first
    assert_instance_of OMF::SFA::Model::Node, n
    assert_equal n.name, 'n1'
    assert_equal n.interfaces.first.name, 'n1:if0'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_a_new_resource_which_contains_a_complex_Array_resource_that_refers_to_already_existing_resources
    i = OMF::SFA::Model::Interface.create({:name => 'i1'})
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/nodes")}
    opts[:req].expect(:body, "{\"name\":\"n1\",\"interfaces_attributes\":[{\"name\":\"#{i.name}\"}]}")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_create_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('nodes', opts) 
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    node = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, node
    assert_equal node["name"], "n1"

    # # check if it is in the db
    n = OMF::SFA::Model::Node.first
    assert_instance_of OMF::SFA::Model::Node, n
    assert_equal n.name, 'n1'
    assert_equal n.interfaces.first.name, 'i1'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_update_a_resource
    c = OMF::SFA::Model::Channel.create({:name => '1', :frequency => '2.412GHz'})
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/channels")}
    opts[:req].expect(:body, "{  \"uuid\":\"#{c.uuid}\",  \"frequency\":\"2.416GHz\"}")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/channels"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_modify_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_put('channels', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    channel = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, channel
    assert_equal channel["frequency"], "2.416GHz"

    # check if it is in the db
    c = OMF::SFA::Model::Channel.first
    assert_instance_of OMF::SFA::Model::Channel, c
    assert_equal c.name, '1'
    assert_equal c.frequency, '2.416GHz'

    opts[:req].verify
    authorizer.verify
  end

  def test_that_it_can_delete_a_resource
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/nodes")}
    opts[:req].expect(:body, "{  \"uuid\":\"#{r.uuid}\" }")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/nodes"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_release_resource?, true, [Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_delete('nodes', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    resp = JSON.parse(json)["resource_response"]["response"]
    assert_equal resp, 'OK'

    # check if it is in the db
    r = OMF::SFA::Model::Node.first
    assert_equal r, nil

    opts[:req].verify
    authorizer.verify
  end

  # Lease related tests
  def test_it_can_list_leases
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    a = OMF::SFA::Model::Account.create(:name => 'root')
    time1 = Time.now
    time2 = Time.now + 36000
    l = OMF::SFA::Model::Lease.create(:account => a, :name => 'l1', :valid_from => time1, :valid_until => time2)
    r.leases << l
    r.save

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    4.times {opts[:req].expect(:path, "/resources/leases")}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_view_lease?, true, [Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_get('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    leases = JSON.parse(json)["resource_response"]["resources"]
    assert_instance_of Array, leases
    lease = leases.first
    assert_equal lease["name"], 'l1'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_will_only_list_leases_that_the_status_is_pending_accepted_or_active
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    a = OMF::SFA::Model::Account.create(:name => 'root')
    time1 = Time.now
    time2 = Time.now + 36000
    l1 = OMF::SFA::Model::Lease.create(:account => a, :name => 'l1', :valid_from => time1, :valid_until => time2, :status => 'accepted')
    r.leases << l1
    r.save

    l2 = OMF::SFA::Model::Lease.create(:account => a, :name => 'l2', :valid_from => time1, :valid_until => time2, :status => 'cancelled')
    r.leases << l2
    r.save

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    4.times {opts[:req].expect(:path, "/resources/leases")}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_view_lease?, true, [Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_get('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    leases = JSON.parse(json)["resource_response"]["resources"]
    assert_instance_of Array, leases
    lease = leases.first
    assert_equal lease["name"], 'l1'
    assert_equal leases.size, 1

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_a_new_lease
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    @manager.manage_resource(r)
    a = OMF::SFA::Model::Account.create(:name => 'account1')
    time1 = "2014-06-24 18:00:00 +0300"
    time2 = "2014-06-24 19:00:00 +0300"

    l_json = "{ \"name\": \"l1\", \"valid_from\": \"#{time1}\", \"valid_until\": \"#{time2}\", \"account\":{\"name\": \"account1\"}, \"components_attributes\":[{\"uuid\": \"#{r.uuid}\"}]}"

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/leases")}
    opts[:req].expect(:body, l_json)
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_create_resource?, true, [Object, Object])}
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    resp = JSON.parse(json)["resource_response"]["resource"]
    assert_equal resp["status"], 'accepted'
    assert_equal resp["valid_from"], "2014-06-24 18:00:00 +0300"
    assert_equal resp["valid_until"], "2014-06-24 19:00:00 +0300"
    assert_equal resp["components"].size, 2

    # # check if it is in the db
    l = OMF::SFA::Model::Lease.first
    assert_equal l[:name], "l1"
    assert_equal l[:valid_from], Time.parse(time1)
    assert_equal l[:valid_until], Time.parse(time2)
    assert_equal l.components.first.uuid, r.uuid
    refute_nil l.components[1].uuid
    # refute_equal l.components[0].uuid, l.components[1].uuid
    # l.components.first.name.must_equal("r1")

    opts[:req].verify
    authorizer.verify
  end

  def test_it_wont_lease_a_non_existent_component
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    @manager.manage_resource(r)
    a = OMF::SFA::Model::Account.create(:name => 'account1')
    time1 = "2014-06-24 18:00:00 +0300"
    time2 = "2014-06-24 19:00:00 +0300"

    l_json = "{ \"name\": \"l1\", \"valid_from\": \"#{time1}\", \"valid_until\": \"#{time2}\", \"account\":{\"name\": \"account1\"}, \"components\":[{\"name\": \"r1\"},{\"name\":\"r2\"}]}"

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/leases")}
    opts[:req].expect(:body, l_json)
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_create_resource?, true, [Object, Object])}
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    lease = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, lease
    assert_equal lease["name"], "l1"
    # assert_equal lease["account"]["name"], "account1"

    # check if it is in the db
    l = OMF::SFA::Model::Lease.first
    assert_equal l.name, "l1"
    assert_equal l.components.first.name, "r1"
    assert_instance_of Time, l.valid_from
    assert_equal l.valid_from, time1
    assert_instance_of Time, l.valid_until
    assert_equal l.valid_until, time2

    l = OMF::SFA::Model::Lease.all
    assert_equal l.size, 1

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_update_a_lease 
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    @manager.manage_resource(r)
    a = OMF::SFA::Model::Account.create(:name => 'account1')
    t1 = Time.now
    t2 = (t1 + 100)
    l = OMF::SFA::Model::Lease.create(name: 'l1', valid_from: t1, valid_until: t2, account_id: a.id)
    l_json = "{ \"uuid\": \"#{l.uuid}\", \"valid_from\": \"#{t1 + 50}\" }"

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/leases")}
    opts[:req].expect(:body, l_json)
    2.times {opts[:req].expect(:content_type, 'application/json')}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_modify_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_put('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    lease = JSON.parse(json)["resource_response"]["resource"]
    assert_instance_of Hash, lease
    assert_equal lease["name"], "l1"
    assert_equal lease["valid_from"], (t1 + 50).to_s
    
    # # check if it is in the db
    l = OMF::SFA::Model::Lease.first
    assert_equal l.name, "l1"
    assert_equal l.valid_from, (t1 + 50).to_s

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_delete_a_lease
    r = OMF::SFA::Model::Node.create({:name => 'r1'})
    @manager.manage_resource(r)
    a = OMF::SFA::Model::Account.create(:name => 'account1')
    t1 = Time.now
    t2 = (t1 + 100)
    l = OMF::SFA::Model::Lease.create(name: 'l1', valid_from: t1, valid_until: t2, account_id: a.id)
    # l.components << r
    # l.save
    cr = @scheduler.create_child_resource({uuid: r.uuid}, 'Node')
    @scheduler.lease_component(l, cr)

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/leases")}
    opts[:req].expect(:body, "{ \"uuid\": \"#{l.uuid}\" }")
    2.times {opts[:req].expect(:content_type, 'application/json')}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/leases"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_release_lease?, true, [Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_delete('leases', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json
    
    resp = JSON.parse(json)["resource_response"]["response"]
    assert_equal resp, 'OK'

    # # check if it is in the db
    lease = OMF::SFA::Model::Lease.first
    assert_equal lease.components.size, 1
    assert_equal lease.components.first.id, r.id
    assert_equal lease.status, 'cancelled'

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_create_an_account 
    l_json = "{ \"name\": \"ac_name\" }"

    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {})
    2.times {opts[:req].expect(:path, "/resources/accounts")}
    opts[:req].expect(:body, l_json)
    2.times {opts[:req].expect(:content_type, 'application/json')}
    3.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/accounts"})}

    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_create_resource?, true, [Object, Object])}
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_post('accounts', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    resp = JSON.parse(json)["resource_response"]["resource"]
    assert_equal resp["name"], "ac_name"

    opts[:req].verify
    authorizer.verify
  end

  def test_it_can_add_an_ssh_key_to_an_user
    c = OMF::SFA::Model::User.create({:name => 'username1'})
    opts = {}
    opts[:req] = MiniTest::Mock.new
    opts[:req].expect(:params, {add_key: "the_ssh_key", uuid: c.uuid})
    # 2.times {opts[:req].expect(:path, "/resources/users")}
    # 2.times {opts[:req].expect(:content_type, 'application/json')}
    2.times {opts[:req].expect(:env, {"REQUEST_PATH" => "/resources/users"})}

    authorizer = MiniTest::Mock.new
    authorizer.expect(:can_view_resource?, true, [Object])
    authorizer.expect(:can_modify_resource?, true, [Object, Object])
    1.times {opts[:req].expect(:session, {authorizer: authorizer})}

    type, json = @rest.on_put('users', opts)
    assert_instance_of String, type
    assert_equal type, "application/json"
    assert_instance_of String, json

    resp = JSON.parse(json)["resource_response"]["response"]
    assert_equal resp, "OK"

    # # check if it is in the db
    u = OMF::SFA::Model::User.first
    assert_instance_of OMF::SFA::Model::User, c
    assert_equal c.keys.first.ssh_key, "the_ssh_key"

    opts[:req].verify
    authorizer.verify
  end
end # Class AMManager
