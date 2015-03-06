require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

# Must use this class as the base class for your tests
class Component < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def test_that_can_create_a_component
    component = OMF::SFA::Model::Component.create(name: 'component1')
    assert_instance_of OMF::SFA::Model::Component, component
  end

  def test_that_can_create_a_component_with_an_account
    account = OMF::SFA::Model::Account.create(name: 'account1')
    component = OMF::SFA::Model::Component.create(name: 'component1', account: account)
    assert_instance_of OMF::SFA::Model::Component, component
    assert_equal account, component.account
  end

  def test_that_can_search_components_with_an_account
    account = OMF::SFA::Model::Account.create(name: 'account1')
    OMF::SFA::Model::Component.create(name: 'component1', urn: 'urn1', account: account)

    component = OMF::SFA::Model::Component.where(account_id: account.id, urn: 'urn1').first
    assert_instance_of OMF::SFA::Model::Component, component
    assert_equal account, component.account
  end
end
