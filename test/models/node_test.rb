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
class Node < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def test_that_can_create_a_node
    res = OMF::SFA::Model::Node.create(name: 'node1')
    assert_instance_of OMF::SFA::Model::Node, res
  end

  def test_that_can_find_a_node_with_urn
    res = OMF::SFA::Model::Node.create(name: 'node1')

    nod = OMF::SFA::Model::Node.first(urn: res.urn)

    assert_instance_of OMF::SFA::Model::Node, res
    assert_equal res, nod
  end
end # Class Resource

