require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'
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
class AMManager < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def before_setup
    @manager = OMF::SFA::AM::AMManager.new(nil)
  end

  def test_that_can_manage_a_resource
    account = OMF::SFA::Model::Account.create(name: 'account1')
    
    @manager.stub :_get_nil_account, account do
      res = OMF::SFA::Model::Node.create(name: 'node1')
      @manager.manage_resource(res)
      assert_equal account, OMF::SFA::Model::Node.first(name: 'node1').account
    end
  end

  def test_that_can_manage_multiple_resources
    account = OMF::SFA::Model::Account.create(name: 'account1')

    @manager.stub :_get_nil_account, account do
      node1 = OMF::SFA::Model::Node.create(name: 'node1')
      node2 = OMF::SFA::Model::Node.create(name: 'node2')
      @manager.manage_resources([node1, node2])
      assert_equal account, OMF::SFA::Model::Node.first(name: 'node1').account
      assert_equal account, OMF::SFA::Model::Node.first(name: 'node2').account
    end
  end

  def test_that_can_find_an_existing_account_instead_of_creating
    account = OMF::SFA::Model::Account.create(name: 'account1')

    @manager.stub :find_account, account do

      a = @manager.find_or_create_account(nil, nil)
      assert_same a, account
      assert_equal 1, OMF::SFA::Model::Account.count
    end
  end

  def test_that_can_create_an_account_if_it_doesnt_exist
    authorizer = Minitest::Mock.new
    authorizer.expect :can_create_account?, true
    @manager.liaison = Minitest::Mock.new
    @manager.liaison.expect :create_account, true, [OMF::SFA::Model::Account]

    account = @manager.find_or_create_account({name: 'account1'}, authorizer)
    assert_instance_of OMF::SFA::Model::Account, account
    assert_equal account.name, 'account1'

    authorizer.verify
    @manager.liaison.verify
  end

  def test_that_can_raise_an_exception_if_create_account_is_not_allowed
    authorizer = Minitest::Mock.new
    authorizer.expect :can_create_account?, false

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.find_or_create_account({name: 'account1'}, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_find_an_existing_account
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_account?, true, [OMF::SFA::Model::Account]
    account = OMF::SFA::Model::Account.create(name: 'account1')

    a = @manager.find_account({name: 'account1'}, authorizer)
    assert_equal account, a

    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_no_account_exists
    assert_raises OMF::SFA::AM::UnavailableResourceException do
      @manager.find_account({name: 'account1'}, nil)
    end
  end

  def test_that_can_raise_an_exception_if_view_account_is_not_allowed
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_account?, false, [OMF::SFA::Model::Account]
    account = OMF::SFA::Model::Account.create(name: 'account1')

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.find_account({name: 'account1'}, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_return_all_accounts_except_the_default
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_account?, true, [OMF::SFA::Model::Account]
    account = OMF::SFA::Model::Account.create(name: '__default__')
    a1 = OMF::SFA::Model::Account.create(name: 'account1')

    accounts = @manager.find_all_accounts(authorizer)
    assert_equal [a1], accounts

    authorizer.verify
  end

  def test_that_wont_return_unauthorized_accounts
    authorizer = Minitest::Mock.new
    a1 = OMF::SFA::Model::Account.create(name: 'account1')
    a2 = OMF::SFA::Model::Account.create(name: 'account2')
    authorizer.expect :can_view_account?, false, [a1]
    authorizer.expect :can_view_account?, true, [a2]

    accounts = @manager.find_all_accounts(authorizer)
    assert_equal [a2], accounts

    authorizer.verify
  end

  def test_that_can_renew_a_given_account
    authorizer = Minitest::Mock.new
    @manager.liaison = Minitest::Mock.new
    @manager.liaison.expect :create_account, true, [OMF::SFA::Model::Account]
    t1 = Time.now
    t2 = Time.now
    account = OMF::SFA::Model::Account.create(name: 'account1', valid_until: t1)
    authorizer.expect :can_renew_account?, true, [account, t2]

    @manager.renew_account_until(account, t2, authorizer)
    assert_equal t2.to_i, OMF::SFA::Model::Account.first(name: 'account1').valid_until.to_i

    authorizer.verify
    @manager.liaison.verify
  end

  def test_that_can_raise_an_exception_if_renew_account_is_not_allowed
    authorizer = Minitest::Mock.new
    t1 = Time.now
    t2 = Time.now
    account = OMF::SFA::Model::Account.create(name: 'account1', valid_until: t1)
    authorizer.expect :can_renew_account?, false, [account, t2]

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.renew_account_until(account, t2, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_close_an_account
    authorizer = Minitest::Mock.new
    @manager.liaison = Minitest::Mock.new
    @manager.liaison.expect :close_account, true, [OMF::SFA::Model::Account]

    account = OMF::SFA::Model::Account.create(name: 'account1')

    @manager.stub :find_account, account do
      @manager.stub :release_all_components_for_account, true do
        authorizer.expect :can_close_account?, true, [account]
        @manager.close_account(account, authorizer)
        assert OMF::SFA::Model::Account.first(name: 'account1').closed?
      end
    end

    authorizer.verify
    @manager.liaison.verify
  end

  def test_that_can_raise_an_exception_if_close_account_is_not_allowed
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')

    @manager.stub :find_account, account do
      authorizer.expect :can_close_account?, false, [account]
      assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
        @manager.close_account(account, authorizer)
      end
    end

    authorizer.verify
  end

  def test_that_can_find_an_existing_user_and_change_its_keys
    user = OMF::SFA::Model::User.create(name: 'user1')
    user.add_key(OMF::SFA::Model::Key.create(name: 'key1'))

    @manager.stub :find_user, user do
      u = @manager.find_or_create_user(user, ['key'])
      assert_equal u, OMF::SFA::Model::User.first(name: 'user1')
    end

    assert_equal 'key', OMF::SFA::Model::User.first(name: 'user1').keys.first.ssh_key
    assert_equal 1, OMF::SFA::Model::Key.count
  end

  def test_that_can_create_a_user_if_it_doesnt_exist
    user = @manager.find_or_create_user({name: 'user1'}, ['key1'])

    assert_instance_of OMF::SFA::Model::User, user
    assert_equal 'user1', user.name
    assert_equal 'key1', OMF::SFA::Model::User.first.keys.first.ssh_key
  end

  def test_that_can_find_an_existing_user
    @manager.find_or_create_user({name: 'user1'})
    
    user = @manager.find_user(name: 'user1')
    assert_instance_of OMF::SFA::Model::User, user
    assert_equal 'user1', user.name
  end

  def test_that_can_raise_an_exception_if_no_user_is_found
    assert_raises OMF::SFA::AM::UnavailableResourceException do
      @manager.find_user({name: 'user1'})
    end
  end

  def test_that_can_find_an_existing_lease
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_lease?, true, [OMF::SFA::Model::Lease]
    lease = OMF::SFA::Model::Lease.create(name: 'lease1')

    l = @manager.find_lease({name: 'lease1'}, authorizer)
    assert_equal lease, l

    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_view_lease_is_not_allowed
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_lease?, false, [OMF::SFA::Model::Lease]
    lease = OMF::SFA::Model::Lease.create(name: 'lease1')

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.find_lease({name: 'lease1'}, authorizer)
    end
    
    authorizer.verify
  end

  def test_that_can_find_an_existing_lease_instead_of_creating
    lease = OMF::SFA::Model::Lease.create(name: 'lease1')

    @manager.stub :find_lease, lease do
      l = @manager.find_or_create_lease({name: 'lease1'}, nil)
      assert_same lease, l
      assert_equal 1, OMF::SFA::Model::Lease.count
    end
  end

  def test_that_can_create_a_lease_if_it_doesnt_exist
    authorizer = Minitest::Mock.new
    authorizer.expect :can_create_resource?, true, [{name: 'lease1'}, 'lease']
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    scheduler.expect :add_lease_events_on_event_scheduler, nil, [OMF::SFA::Model::Lease]
    scheduler.expect :list_all_event_scheduler_jobs, nil, []
    scheduler.expect :event_scheduler, Minitest::Mock.new, []
    scheduler.expect :event_scheduler=, Minitest::Mock.new, [Minitest::Mock]
    scheduler.event_scheduler = Minitest::Mock.new
    scheduler.event_scheduler.expect :jobs, [], []

    lease = @manager.find_or_create_lease({name: 'lease1'}, authorizer)
    assert_instance_of OMF::SFA::Model::Lease, lease
    assert_equal 'lease1', lease.name

    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_create_lease_is_not_allowed
    authorizer = Minitest::Mock.new
    authorizer.expect :can_create_resource?, false, [{name: 'lease1'}, 'lease']

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.find_or_create_lease({name: 'lease1'}, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_find_all_leases
    authorizer = Minitest::Mock.new
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1')
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2')
    2.times { authorizer.expect :can_view_lease?, true, [OMF::SFA::Model::Lease]}

    leases = @manager.find_all_leases(authorizer)
    assert_equal [l1, l2], leases

    authorizer.verify
  end

  def test_that_can_return_only_authorized_leases
    authorizer = Minitest::Mock.new
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1')
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2')
    authorizer.expect :can_view_lease?, true, [l1]
    authorizer.expect :can_view_lease?, false, [l2]

    leases = @manager.find_all_leases(authorizer)
    assert_equal [l1], leases

    authorizer.verify
  end

  def test_that_can_filter_leases_by_their_status
    authorizer = Minitest::Mock.new
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted')
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', status: 'active')
    OMF::SFA::Model::Lease.create(name: 'lease3', status: 'past')
    2.times { authorizer.expect :can_view_lease?, true, [OMF::SFA::Model::Lease] }

    leases = @manager.find_all_leases(nil, ['accepted', 'active'], authorizer)
    assert_equal [l1, l2], leases

    authorizer.verify
  end

  def test_that_can_filter_leases_by_their_account
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted', account: account)
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', status: 'active')
    OMF::SFA::Model::Lease.create(name: 'lease3', status: 'past')
    2.times { authorizer.expect :can_view_lease?, true, [OMF::SFA::Model::Lease] }

    leases = @manager.find_all_leases(account, ['accepted', 'active'], authorizer)
    assert_equal [l1], leases

    authorizer.verify
  end

  def test_that_can_modify_a_lease
    authorizer = Minitest::Mock.new
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted')
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    scheduler.expect :modify_lease_events_from_event_scheduler, nil, [OMF::SFA::Model::Lease]
    scheduler.expect :add_lease_events_on_event_scheduler, nil, [OMF::SFA::Model::Lease]
    scheduler.expect :remove_lease_events_from_event_scheduler, nil, [OMF::SFA::Model::Lease]
    scheduler.expect :update_lease_events_on_event_scheduler, nil, [OMF::SFA::Model::Lease]
    scheduler.expect :list_all_event_scheduler_jobs, nil, []
    scheduler.expect :event_scheduler, Minitest::Mock.new, []
    scheduler.expect :event_scheduler=, Minitest::Mock.new, [Minitest::Mock]
    scheduler.event_scheduler = Minitest::Mock.new
    scheduler.event_scheduler.expect :jobs, [], []
    authorizer.expect :can_modify_lease?, true, [OMF::SFA::Model::Lease]

    l1 = @manager.modify_lease({status: 'past'}, lease, authorizer)

    assert_equal OMF::SFA::Model::Lease.find(name: 'lease1').status, l1.status

    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_modify_lease_is_not_allowed
    authorizer = Minitest::Mock.new
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted')

    authorizer.expect :can_modify_lease?, false, [OMF::SFA::Model::Lease]

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.modify_lease({status: 'past'}, lease, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_release_a_lease
    authorizer = Minitest::Mock.new
    manager = OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new)
    manager.get_scheduler.event_scheduler = Minitest::Mock.new
    3.times {manager.get_scheduler.event_scheduler.expect :jobs, [], []}

    t = Time.now
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted', valid_from: t, valid_until: t + 100, status: 'accepted')
    node = OMF::SFA::Model::Node.create(name: 'node1')
    node_child = OMF::SFA::Model::Node.create(name: 'child_node1', parent: node)
    node.add_lease(lease)
    node_child.add_lease(lease)

    authorizer.expect :can_release_lease?, true, [OMF::SFA::Model::Lease]
    l1 = manager.release_lease(lease, authorizer)
    l2 = OMF::SFA::Model::Lease.first(name: 'lease1')

    assert_equal l2, l1
    assert_equal 'cancelled', l2.status
    assert_equal 1, l2.components.count
    assert_equal 'node1', l2.components.first.name
    assert_equal 1, OMF::SFA::Model::Node.count
    assert OMF::SFA::Model::Node.first(name: 'node1')
    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_release_lease_is_not_allowed
    authorizer = Minitest::Mock.new
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted')

    authorizer.expect :can_release_lease?, false, [OMF::SFA::Model::Lease]

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.release_lease(lease, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_return_a_resource_if_object_is_given
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Node]
    node = OMF::SFA::Model::Node.create(name: 'node1')

    n = @manager.find_resource(node, 'node', authorizer)
    assert_equal node, n

    authorizer.verify
  end

  def test_that_can_find_a_resource_by_its_description
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Node]
    node = OMF::SFA::Model::Node.create(name: 'node1')

    n = @manager.find_resource({name: 'node1'}, 'node', authorizer)
    assert_equal node, n

    authorizer.verify
  end

  def test_that_can_raise_an_exception_if_view_resource_is_not_allowed
    authorizer = Minitest::Mock.new
    authorizer.expect :can_view_resource?, false, [OMF::SFA::Model::Node]
    node = OMF::SFA::Model::Node.create(name: 'node1')

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.find_resource({name: 'node1'}, 'node', authorizer)
    end

    authorizer.verify
  end

  def test_that_can_find_resources_by_their_description
    authorizer = Minitest::Mock.new
    2.times { authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Node] }
    node1 = OMF::SFA::Model::Node.create(name: 'node1', hardware_type: 'grid')
    node2 = OMF::SFA::Model::Node.create(name: 'node2', hardware_type: 'grid')
    node3 = OMF::SFA::Model::Node.create(name: 'node3', hardware_type: 'other')

    nodes = @manager.find_all_resources({hardware_type: 'grid'}, 'node', authorizer)
    assert_equal [node1, node2], nodes

    authorizer.verify
  end

  def test_that_can_return_only_authorized_resources
    authorizer = Minitest::Mock.new
    node1 = OMF::SFA::Model::Node.create(name: 'node1', hardware_type: 'grid')
    node2 = OMF::SFA::Model::Node.create(name: 'node2', hardware_type: 'grid')
    node3 = OMF::SFA::Model::Node.create(name: 'node3', hardware_type: 'other')
    authorizer.expect :can_view_resource?, true, [node1]
    authorizer.expect :can_view_resource?, false, [node2]


    nodes = @manager.find_all_resources({hardware_type: 'grid'}, 'node', authorizer)
    assert_equal [node1], nodes

    authorizer.verify
  end

  def test_that_can_find_all_available_components_in_a_timeslot
    authorizer = Minitest::Mock.new
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    
    account = OMF::SFA::Model::Account.create(name: 'account1')
    node1 = OMF::SFA::Model::Node.create(hardware_type: 'grid', account: account)
    node2 = OMF::SFA::Model::Node.create(hardware_type: 'grid', account: account)
    node3 = OMF::SFA::Model::Node.create(hardware_type: 'grid')

    2.times { authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Node] }
    scheduler.expect :component_available?, true, [node1, nil, nil]
    scheduler.expect :component_available?, false, [node2, nil, nil]

    @manager.stub :_get_nil_account, account do
      components = @manager.find_all_available_components({hardware_type: 'grid'}, 'node', nil, nil, authorizer)
      assert_equal [node1], components
    end
    
    authorizer.verify
    scheduler.verify
  end

  def test_that_can_find_all_resources_for_account
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')
    node1 = OMF::SFA::Model::Node.create(name: 'node1', domain: 'domain1', account: account)
    node2 = OMF::SFA::Model::Node.create(name: 'node2', account: account)
    node3 = OMF::SFA::Model::Node.create(name: 'node3')

    authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Resource]
    authorizer.expect :can_view_resource?, false, [OMF::SFA::Model::Resource]
    resources = @manager.find_all_resources_for_account(account, authorizer)
    assert_equal 1, resources.count
    assert_equal node1.name, resources.first.name

    authorizer.verify
  end

  def test_that_can_find_all_components_for_account
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')
    node1 = OMF::SFA::Model::Node.create(name: 'node1', domain: 'domain1', account: account)
    node2 = OMF::SFA::Model::Node.create(name: 'node2', account: account)
    node3 = OMF::SFA::Model::Node.create(name: 'node3')

    authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Component]
    authorizer.expect :can_view_resource?, false, [OMF::SFA::Model::Component]
    components = @manager.find_all_components_for_account(account, authorizer)
    assert_equal 1, components.count
    assert_equal node1.name, components.first.name

    authorizer.verify
  end

  def test_that_can_find_all_components
    authorizer = Minitest::Mock.new
    component1 = OMF::SFA::Model::Component.create(name: 'component1')
    node1 = OMF::SFA::Model::Node.create(name: 'node1')
    node2 = OMF::SFA::Model::Node.create(name: 'node2')

    authorizer.expect :can_view_resource?, true, [OMF::SFA::Model::Component]
    authorizer.expect :can_view_resource?, false, [OMF::SFA::Model::Component]
    components = @manager.find_all_components({type: 'OMF::SFA::Model::Node'}, authorizer)
    assert_equal 1, components.count
    assert_instance_of OMF::SFA::Model::Node, components.first

    authorizer.verify
  end

  def test_that_can_find_a_resource_instead_of_creating_a_new_one
    node = OMF::SFA::Model::Node.create(name: 'node1')

    @manager.stub :find_resource, node do
      resource = @manager.find_or_create_resource({name: 'node1'}, nil, nil)
      assert_equal node, resource
    end
  end

  def test_that_can_create_a_resource_if_it_does_not_exist
    @manager.stub :create_resource, true do
      assert @manager.find_or_create_resource({name: 'node1'}, 'node', nil)
    end
  end

  def test_that_can_raise_an_exception_if_create_resource_is_not_allowed
    authorizer = Minitest::Mock.new

    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      authorizer.expect :can_create_resource?, false, [{name: 'node1'}, 'node']
      @manager.create_resource({name: 'node1'}, 'node', authorizer)
    end
    authorizer.verify
  end

  def test_that_can_create_a_managed_resource
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')

    @manager.stub :_get_nil_account, account do
      authorizer.expect :can_create_resource?, true, [{name: 'node1'}, 'node']
      resource = @manager.create_resource({name: 'node1'}, 'node', authorizer)
      assert_equal account, resource.account
      assert_equal 'node1', resource.name
    end

    authorizer.verify
  end

  def test_that_can_create_a_child_resource
    authorizer = Minitest::Mock.new
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    account = OMF::SFA::Model::Account.create(name: 'account1')

    authorizer.expect :can_create_resource?, true, [{name: 'node1', account_id: account.id}, 'node']
    scheduler.expect :create_child_resource, true, [{name: 'node1', account_id: account.id}, 'node']
    assert @manager.create_resource({name: 'node1', account_id: account.id}, 'node', authorizer)


    authorizer.verify
    scheduler.verify
  end

  def test_that_can_find_or_create_resource_for_an_account
    authorizer = Minitest::Mock.new
    account = OMF::SFA::Model::Account.create(name: 'account1')

    authorizer.expect :account, account

    @manager.stub :find_or_create_resource, true do
      assert @manager.find_or_create_resource_for_account({name: 'node1'}, 'node', authorizer)
    end

    authorizer.verify
  end

  def test_that_can_create_resources_from_rspec
    skip
  end

  def test_that_can_release_a_resource
    authorizer = Minitest::Mock.new
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    node = OMF::SFA::Model::Node.create(name: 'node1')

    authorizer.expect :can_release_resource?, true, [node]
    scheduler.expect :release_resource, true, [node]
    assert @manager.release_resource(node, authorizer)

    authorizer.verify
    scheduler.verify
  end

  def test_that_can_raise_an_exception_if_release_resource_is_not_allowed
    authorizer = Minitest::Mock.new
    node = OMF::SFA::Model::Node.create(name: 'node1')

    authorizer.expect :can_release_resource?, false, [node]
    
    assert_raises OMF::SFA::AM::InsufficientPrivilegesException do
      @manager.release_resource(node, authorizer)
    end

    authorizer.verify
  end

  def test_that_can_release_multiple_resources
    authorizer = Minitest::Mock.new
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    node1 = OMF::SFA::Model::Node.create(name: 'node1')
    node2 = OMF::SFA::Model::Node.create(name: 'node2')

    authorizer.expect :can_release_resource?, true, [node1]
    authorizer.expect :can_release_resource?, true, [node2]
    scheduler.expect :release_resource, true, [node1]
    scheduler.expect :release_resource, true, [node2]
    assert @manager.release_resources([node1,node2], authorizer)

    authorizer.verify
    scheduler.verify
  end

  def test_that_release_all_components_for_account
    authorizer = Minitest::Mock.new
    @manager = OMF::SFA::AM::AMManager.new(scheduler = Minitest::Mock.new)
    account = OMF::SFA::Model::Account.create(name: 'account1')
    node = OMF::SFA::Model::Node.create(name: 'node1', account: account)
    OMF::SFA::Model::Node.create(name: 'node2')

    authorizer.expect :can_view_resource?, true, [node]
    authorizer.expect :can_release_resource?, true, [node]
    scheduler.expect :release_resource, true, [node]
    assert @manager.release_all_components_for_account(account, authorizer)

    authorizer.verify
    scheduler.verify
  end

  def test_that_can_update_lease_from_rspec
    skip
  end

  def test_that_can_update_leases_from_rspec
    skip
  end

end # Class AMManager
