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

  def test_that_can_release_a_resource_with_leases
    account1 = OMF::SFA::Model::Account.create(name: 'account1')
    account2 = OMF::SFA::Model::Account.create(name: 'account2')
    parent = OMF::SFA::Model::Node.create(name: 'node1', account_id: account1.id)
    child = OMF::SFA::Model::Node.create(name: 'node1', account_id: account2.id, parent_id: parent.id)
    t1 = Time.now
    t2 = t1 + 100
    lease = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2)
    lease.add_component(parent)
    lease.add_component(child)

    assert @scheduler.release_resource(child)
    assert_equal lease.reload, parent.leases.first
    assert_equal 'cancelled', OMF::SFA::Model::Lease.first(name: 'lease1').status
  end
end
