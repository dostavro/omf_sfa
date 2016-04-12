require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'
require 'omf-sfa/am/am_scheduler'
require 'omf_common/load_yaml'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

OMF::Common::Loggable.init_log('am_scheduler', { :searchPath => File.join(File.dirname(__FILE__), 'am_manager') })
::Log4r::Logger.global.level = ::Log4r::OFF

# Must use this class as the base class for your tests
class AMScheduler < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def before_setup
    @scheduler = OMF::SFA::AM::AMScheduler.new
  end

  def test_that_can_create_a_child_resource
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    node1 = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)

    @scheduler.stub :get_nil_account, account1 do
      node2 = @scheduler.create_child_resource({name: 'node1', account_id: account2.id}, 'node')
      node1 = OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id)

      assert_equal node1, node2.parent
      assert_equal node2.name, node1.children.first.name
      assert_equal account2, node2.account
    end
  end

  def test_that_can_release_a_resource
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)

    assert @scheduler.release_resource(child)
    assert_nil OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id)
    assert_empty OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).children
  end

  def test_tha_can_lease_a_component_1
    @scheduler.am_policies = Minitest::Mock.new
    @scheduler.am_policies.expect :valid?, true, [OMF::SFA::Model::Lease, OMF::SFA::Model::Node]
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    t1 = Time.now
    t2 = t1 + 100
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2)

    assert @scheduler.lease_component(lease, child)
    lease.reload
    assert_equal lease, OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).leases.first
    assert_equal lease, OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id).leases.first
  end

  def test_tha_can_lease_a_component_2
    @scheduler.am_policies = Minitest::Mock.new
    @scheduler.am_policies.expect :valid?, true, [OMF::SFA::Model::Lease, OMF::SFA::Model::Node]
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    
    t1 = '2014-12-23T15:00:00+02:00'
    t2 = '2014-12-23T17:00:00+02:00'
    lease1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2)
    lease1.add_component(parent)

    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    lease2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: '2014-12-23T18:00:00+02:00', valid_until: '2014-12-23T19:00:00+02:00')

    assert @scheduler.lease_component(lease2, child)
    lease2.reload
    assert_equal lease2, OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).leases.last
    assert_equal lease2, OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id).leases.last
  end

  def test_that_cannot_lease_a_component_that_is_already_leased_1
    @scheduler.am_policies = Minitest::Mock.new
    @scheduler.am_policies.expect :valid?, true, [OMF::SFA::Model::Lease, OMF::SFA::Model::Node]
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    
    t1 = '2014-12-23T15:00:00+02:00'
    t2 = '2014-12-23T17:00:00+02:00'
    lease1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, status: 'accepted')
    lease1.add_component(parent)

    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    lease2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: '2014-12-23T16:00:00+02:00', valid_until: '2014-12-23T17:00:00+02:00')

    refute @scheduler.lease_component(lease2, child)
    assert_equal 1, OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).leases.count
    assert_empty OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id).leases
  end

  def test_that_cannot_lease_a_component_that_is_already_leased_2
    @scheduler.am_policies = Minitest::Mock.new
    @scheduler.am_policies.expect :valid?, true, [OMF::SFA::Model::Lease, OMF::SFA::Model::Node]
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    
    t1 = '2014-12-23T15:00:00+02:00'
    t2 = '2014-12-23T17:00:00+02:00'
    lease1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, status: 'accepted')
    lease1.add_component(parent)

    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    lease2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: '2014-12-23T14:00:00+02:00', valid_until: '2014-12-23T18:00:00+02:00')

    refute @scheduler.lease_component(lease2, child)
    assert_equal 1, OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).leases.count
    assert_empty OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id).leases
  end

  def test_that_cannot_lease_a_component_that_is_already_leased_3
    @scheduler.am_policies = Minitest::Mock.new
    @scheduler.am_policies.expect :valid?, true, [OMF::SFA::Model::Lease, OMF::SFA::Model::Node]
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    
    t1 = Time.parse('2014-12-23T15:00:00+02:00')
    t2 = Time.parse('2014-12-23T17:00:00+02:00')
    lease1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, status: 'accepted')
    lease1.add_component(parent)

    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    lease2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t1, valid_until: t2)

    refute @scheduler.lease_component(lease2, child)
    assert_equal 1, OMF::SFA::Model::Node.first(name: 'node1', account_id: account1.id).leases.count
    assert_empty OMF::SFA::Model::Node.first(name: 'node1', account_id: account2.id, parent_id: parent.id).leases
  end

  def test_that_it_can_release_a_lease
    t = Time.now
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted', valid_from: t, valid_until: t + 100, status: 'accepted')
    node = OMF::SFA::Model::Node.create(name: 'node1')
    node_child = OMF::SFA::Model::Node.create(name: 'child_node1', parent: node)
    node.add_lease(lease)
    node_child.add_lease(lease)

    @scheduler.event_scheduler = Minitest::Mock.new
    3.times {@scheduler.event_scheduler.expect :jobs, [], []}

    l1 = @scheduler.release_lease(lease)
    l2 = OMF::SFA::Model::Lease.first(name: 'lease1')

    assert_equal l2, l1
    assert_equal 'cancelled', l2.status
    assert_equal 1, l2.components.count
    assert_equal 'node1', l2.components.first.name
    assert_equal 1, OMF::SFA::Model::Node.count
    assert OMF::SFA::Model::Node.first(name: 'node1')
  end

  def test_that_it_can_delete_a_lease
    t = Time.now
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', status: 'accepted', valid_from: t, valid_until: t + 100, status: 'accepted')
    node = OMF::SFA::Model::Node.create(name: 'node1')
    node_child = OMF::SFA::Model::Node.create(name: 'child_node1', parent: node)
    node.add_lease(lease)
    node_child.add_lease(lease)

    @scheduler.event_scheduler = Minitest::Mock.new
    3.times {@scheduler.event_scheduler.expect :jobs, [], []}

    resp = @scheduler.delete_lease(lease)
    l = OMF::SFA::Model::Lease.first(name: 'lease1')

    assert_equal resp, true
    assert_equal l, nil

    assert_equal 1, OMF::SFA::Model::Node.count
    assert OMF::SFA::Model::Node.first(name: 'node1')
  end

  def test_that_it_can_list_leases
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1')
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2')

    leases = @scheduler.find_all_leases
    assert_equal [l1, l2], leases
  end
end
