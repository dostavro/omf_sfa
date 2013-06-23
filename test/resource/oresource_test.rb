require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'

require 'dm-migrations'
require 'omf-sfa/resource'


include OMF::SFA::Resource

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end


describe OResource do

  describe 'resources as oproperties' do

    before do
      init_dm
    end

    it 'can create an interface when creating a node' do
      node = Node.create(name: 'node1', interfaces: {name: 'node1:if0'})
      node.must_be_kind_of(Node)
      node.interfaces.first.must_be_kind_of(Interface)
    end

    it 'can create an ip when creating an interface' do
      node = Node.create(name: 'node1', interfaces: {name: 'node1:if0', ip: {address: '10.0.0.1'}})
      irf = node.interfaces.first
      irf.must_be_kind_of(Interface)
      irf.ip.must_be_kind_of(Ip)
      irf.ip.address.must_equal('10.0.0.1')
    end

    it 'can create an interface and link to a node' do
      node = Node.create(name: 'node1', interfaces: {name: 'node1:if0', node: {name: 'node1'}})
      node.must_be_kind_of(Node)
      interface = node.interfaces.first
      interface.must_be_kind_of(Interface)
      interface.node.must_equal(node)
    end

    it 'can create a node with an already created interface' do
      interface = Interface.create(name: 'node1:if0')
      node = Node.create(name: 'node1', interfaces: interface)
      interface.node = node
      interface.save
    end

    it 'can create a node with 2 interfaces' do
      node = Node.create(name: 'node1', interfaces: [{name: 'node1:if0'}, {name: 'node1:if1'}])
    end
  end

  describe "Searching with oproperties" do

    before do
      init_dm
      Lease.create(name: 'lease2', status: 'accepted')
    end

    it 'can search with oproperty' do
      lease = Lease.create(name: 'lease1', status: 'pending')
      lease.must_be_kind_of(Lease)
      lease.status.must_equal('pending')

      l = Lease.first(name: 'lease1', status: 'pending')
      lease.must_equal(l)
    end

    it 'can search only with oproperty' do
      lease = Lease.create(name: 'lease1', status: 'pending')
      lease.must_be_kind_of(Lease)
      lease.status.must_equal('pending')

      l = Lease.first(status: 'pending')
      lease.must_equal(l)
    end

    it 'can search with many oproperties' do
      t1 = Time.now
      t2 = Time.now + 3600
      l1 = Lease.create(name: 'l1', valid_from: t1, valid_until: t2)
      l2 = Lease.create(name: 'l1', valid_from: t2, valid_until: t2+3600)

      lease = Lease.first(name: 'l1', valid_from: t1, valid_until: t2)
      lease.must_equal(l1)
    end

    it 'will return nil' do
      lease = Lease.first(status: 'pending')
      lease.must_be_nil
    end

    it 'can search with an object oproperty' do
      Node.create(name: 'node2')
      node = Node.create(name: 'node1', interfaces: {name: 'node1:if0', node: {name: 'node1'}})
      interface = node.interfaces.first
      interface.must_be_kind_of(Interface)
      interface.node = node

      irf = Interface.first(node: node)
      irf.must_equal(interface)

      n = Node.first(interfaces: interface)
      n.must_equal(node)
    end

    it 'will raise an exception when it has wrong properties' do
      lambda do
        l = Lease.first(asdf: "asdgf")
      end.must_raise(ArgumentError)
    end

    it 'can find non functional oproperties' do
      irf1 = Interface.create(name: 'node1:if0')
      irf2 = Interface.create(name: 'node1:if1')
      node = Node.create(name: 'node1', interfaces: [irf1, irf2])
      node.interfaces.must_equal([irf1, irf2])
    end
  end
end
