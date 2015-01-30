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
class Lease < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def test_that_can_create_a_lease
    res = OMF::SFA::Model::Lease.create(name: 'lease1')
    assert_instance_of OMF::SFA::Model::Lease, res
  end

  def test_that_can_find_a_lease_with_urn
    res = OMF::SFA::Model::Lease.create(name: 'Lease1')

    lease = OMF::SFA::Model::Lease.first(urn: res.urn)

    assert_instance_of OMF::SFA::Model::Lease, res
    assert_equal res, lease
  end

  def test_that_it_can_return_it_is_active
    t_now = Time.now
    res = OMF::SFA::Model::Lease.create(name: 'Lease1', valid_from: t_now - 100, valid_until: t_now + 100)

    active = res.active?
    assert_equal active, true
  end

  def test_that_it_can_return_it_is_not_active
    t_now = Time.now
    res = OMF::SFA::Model::Lease.create(name: 'Lease1', valid_from: t_now + 100, valid_until: t_now + 200)

    active = res.active?
    assert_equal active, false
  end
end # Class Resource

