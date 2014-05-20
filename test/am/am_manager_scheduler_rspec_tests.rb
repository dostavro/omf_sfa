require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'dm-migrations'
require 'omf_common/load_yaml'
require 'active_support/inflector'
require 'uuid'

include OMF::SFA::AM

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end

def init_logger
  OMF::Common::Loggable.init_log 'am_manager', :searchPath => File.join(File.dirname(__FILE__), 'am_manager')
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe AMManager do

  init_logger

  init_dm

  before do
    DataMapper.auto_migrate! # reset database
  end

  let (:scheduler) { AMScheduler.new }
  let (:manager) { AMManager.new(scheduler) }

  describe 'resource creation' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'foo'})
      r = OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node1"})
      manager.manage_resource(r)
    end

    it "won't create anything" do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
      </rspec>
      }
      request = Nokogiri.XML(rspec)

      resources = manager.update_resources_from_rspec(request.root, false, authorizer)
      resources.must_be_empty

      authorizer.verify
    end

    it 'will create a node' do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
        </node>
      </rspec>
      }
      request = Nokogiri.XML(rspec)

      3.times {authorizer.expect(:account, @account)}
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      resources = manager.update_resources_from_rspec(request.root, false, authorizer)
      resources.size.must_equal(1)
      node = resources.first

      node.component_name.must_equal("node1")
      node.client_id.must_equal("my_node")

      authorizer.verify
    end

    # it "won't create a node that doesn't exist" do
    #   authorizer = Minitest::Mock.new

    #   rspec = %{
    #   <?xml version="1.0" ?>
    #   <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
    #     <node component_id="urn:publicid:IDN+omf:nitos+node+node100" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" exclusive="true">
    #     </node>
    #   </rspec>
    #   }
    #   request = Nokogiri.XML(rspec)

    #   3.times {authorizer.expect(:account, @account)}
    #   authorizer.expect(:can_create_resource?, true, [Hash, String])
    #   lambda { manager.update_resources_from_rspec(request.root, false, authorizer) }.must_raise(UnknownResourceException)

    #   authorizer.verify
    # end
  end

  describe 'nodes and leases' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'foo'})
      r = OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node1"})
      manager.manage_resource(r)
    end

    it 'will create a node with a lease attached to it' do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease client_id="l1" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="l1"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      4.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')
      node.client_id.must_equal('my_node')

      node.account.must_equal(@account)

      lease = r.select {|v| v.class == OMF::SFA::Resource::Lease}.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)
      lease.client_id.must_equal('l1')

      authorizer.verify
    end

    it 'will create a node with a lease attached to it and ignore the unknown node' do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease client_id="l1" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="l1"/>
        </node>
        <node component_id="urn:publicid:IDN+ple:inria+node+wlab02.pl.sophia.inria.fr">
          <ol:lease_ref id_ref="l1"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      3.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      5.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')
      node.client_id.must_equal('my_node')

      node.account.must_equal(@account)

      lease = r.select {|v| v.class == OMF::SFA::Resource::Lease}.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)
      lease.client_id.must_equal('l1')

      authorizer.verify
    end

    it 'will create a node with an already known lease attached to it' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease id="#{l.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="omf" exclusive="true">
          <ol:lease_ref id_ref="#{l.uuid}"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
      2.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      2.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      node.account.must_equal(@account)

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.must_equal(l)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end

    it 'will attach an additional lease to a node' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      authorizer.expect(:account, @account)
      n = scheduler.create_resource({:urn => "urn:publicid:IDN+omf:nitos+node+node1"}, 'node', {}, authorizer)
      n.must_be_kind_of(OMF::SFA::Resource::Node)

      scheduler.lease_component(l, n)
      n.reload
      n.leases.first.must_equal(l)

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease id="#{l.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <ol:lease client_id="l2" valid_from="2013-01-08T12:00:00Z" valid_until="2013-01-08T14:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="#{l.uuid}"/>
          <ol:lease_ref id_ref="l2"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      3.times {authorizer.expect(:account, @account)}
      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      node.account.must_equal(@account)

      lease = node.leases.select {|v| v.uuid == l.uuid}.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      lease2 = node.leases.select {|v| v.client_id == "l2"}.first
      lease2.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease2.valid_from.must_equal(Time.parse('2013-01-08T12:00:00Z'))
      lease2.valid_until.must_equal(Time.parse('2013-01-08T14:00:00Z'))
      lease2.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      OMF::SFA::Resource::Lease.count.must_equal(2)
      OMF::SFA::Resource::Node.count.must_equal(2)

      authorizer.verify
    end

    it 'should create a node with a lease without using a reference' do
      authorizer = Minitest::Mock.new

      rspec = %{
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease client_id="my_lease" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      4.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      node.account.must_equal(@account)

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end

    it 'will attach 2 leases(1 new and 1 old) to 2 nodes' do
      authorizer = Minitest::Mock.new

      r = OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node2"})
      manager.manage_resource(r)

      l1 = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                              :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                              :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease id="#{l1.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <ol:lease client_id="l2" valid_from="2013-01-08T12:00:00Z" valid_until="2013-01-08T14:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="node1" exclusive="true">
          <ol:lease_ref id_ref="#{l1.uuid}"/>
        </node>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node2" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node2" client_id="node2" exclusive="true">
          <ol:lease_ref id_ref="l2"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      3.times { authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease]) }
      3.times { authorizer.expect(:can_create_resource?, true, [Hash, String]) }
      6.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.select {|v| v.urn == 'urn:publicid:IDN+omf:nitos+node+node1'}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      node.account.must_equal(@account)

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      node = r.select {|v| v.urn == 'urn:publicid:IDN+omf:nitos+node+node2'}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node2')
      node.resource_type.must_equal('node')

      node.account.must_equal(@account)

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T12:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T14:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end
  end # nodes and leases

  describe 'channels, nodes and leases' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'foo'})
      r = []
      r << OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node1"})
      r << OMF::SFA::Resource::Channel.create({:urn => "urn:publicid:IDN+omf:nitos+channel+9"})
      manager.manage_resources(r)
    end

    it 'will reserve a channel' do
      authorizer = Minitest::Mock.new
      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease client_id="l1" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <ol:channel client_id="my_channel" component_id="urn:publicid:IDN+omf:nitos+channel+9" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="9" frequency="2.452GHz">
          <ol:lease_ref id_ref="l1"/>
        </ol:channel>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      4.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      channel = r.select {|v| v.class == OMF::SFA::Resource::Channel}.first
      channel.must_be_kind_of(OMF::SFA::Resource::Channel)
      channel.name.must_equal('9')
      channel.resource_type.must_equal('channel')

      channel.account.must_equal(@account)

      lease = channel.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Channel)

      authorizer.verify
    end

    it 'will attach a lease to a channel and a node' do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease client_id="l1" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <ol:channel client_id="my_channel" component_id="urn:publicid:IDN+omf:nitos+channel+9" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="9" frequency="2.452GHz">
          <ol:lease_ref id_ref="l1"/>
        </ol:channel>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="l1"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      3.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      6.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      channel = r.select {|v| v.class == OMF::SFA::Resource::Channel}.first
      channel.must_be_kind_of(OMF::SFA::Resource::Channel)
      channel.name.must_equal('9')
      channel.resource_type.must_equal('channel')

      channel.account.must_equal(@account)

      lease = channel.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.must_include(channel)

      node = r.select {|v| v.class == OMF::SFA::Resource::Node}.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.leases.first.must_equal(lease)

      authorizer.verify
    end
  end # channel and leases

  describe 'clean state flag' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'foo'})
      r = []
      r << OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node1"})
      r << OMF::SFA::Resource::Node.create({:urn => "urn:publicid:IDN+omf:nitos+node+node2"})
      r << OMF::SFA::Resource::Channel.create({:urn => "urn:publicid:IDN+omf:nitos+channel+9"})
      manager.manage_resources(r)
    end

    it 'will create a new node and lease without deleting the previous records' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      authorizer.expect(:account, @account)
      n = scheduler.create_resource({:urn => "urn:publicid:IDN+omf:nitos+node+node1"}, 'node', {}, authorizer)
      n.must_be_kind_of(OMF::SFA::Resource::Node)

      scheduler.lease_component(l, n)
      n.reload
      n.leases.first.must_equal(l)

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease client_id="l1" valid_from="2013-01-08T12:00:00Z" valid_until="2013-01-08T14:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node2" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node2" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="l1"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_create_resource?, true, [Hash, String])}
      5.times {authorizer.expect(:account, @account)}

      res = manager.update_resources_from_rspec(req.root, false, authorizer)

      res.length.must_equal 2
      node2 = res.select {|v| v.class == OMF::SFA::Resource::Node}.first
      lease = res.select {|v| v.class == OMF::SFA::Resource::Lease}.first

      node2.must_be_kind_of(OMF::SFA::Resource::Node)
      node2.name.must_equal('node2')
      node2.leases.first.must_equal(lease)

      lease.must_be_kind_of(OMF::SFA::Resource::Lease)

      node = OMF::SFA::Resource::Node.first({:name => 'node1', :account => @account})
      node.wont_be_nil
      node.leases.first.wont_be_nil

      node = OMF::SFA::Resource::Node.first({:name => 'node2', :account => @account})
      node.wont_be_nil
      node.leases.first.wont_be_nil

      OMF::SFA::Resource::Node.all({:name => 'node1'}).count.must_equal(2)
      OMF::SFA::Resource::Node.all({:name => 'node2'}).count.must_equal(2)
      OMF::SFA::Resource::Lease.all.count.must_equal(2)

      authorizer.verify
    end

    it 'will unlink a node from a lease and release both' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      authorizer.expect(:account, @account)
      n = scheduler.create_resource({:urn => "urn:publicid:IDN+omf:nitos+node+node1"}, 'node', {}, authorizer)
      n.must_be_kind_of(OMF::SFA::Resource::Node)

      scheduler.lease_component(l, n)
      n.reload
      n.leases.first.must_equal(l)

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
      </rspec>
      }

      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
      authorizer.expect(:can_release_lease?, true, [OMF::SFA::Resource::Lease])
      authorizer.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
      2.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, true, authorizer)
      r.must_be_empty

      OMF::SFA::Resource::Node.first(:name => 'node1').wont_be_nil
      OMF::SFA::Resource::Node.first(:account => @account).must_be_nil

      l.reload
      l.components.first.must_be_nil

      OMF::SFA::Resource::Lease.first(:account => @account).wont_be_nil
      OMF::SFA::Resource::Lease.first(:account => @account).status.must_equal("past")

      authorizer.verify
    end

    it "should cancel a lease" do
      authorizer = Minitest::Mock.new

      l1 = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})
      l2 = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T21:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T22:00:00Z')})

      authorizer.expect(:account, @account)
      n = scheduler.create_resource({:urn => "urn:publicid:IDN+omf:nitos+node+node1"}, 'node', {}, authorizer)
      n.must_be_kind_of(OMF::SFA::Resource::Node)

      scheduler.lease_component(l1, n)
      scheduler.lease_component(l2, n)
      n.reload
      n.leases.first.must_equal(l1)

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease id="#{l1.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="#{l1.uuid}"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])}
      3.times {authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])}
      authorizer.expect(:can_release_lease?, true, [OMF::SFA::Resource::Lease])
      3.times {authorizer.expect(:account, @account)}

      res = manager.update_resources_from_rspec(req.root, true, authorizer)

      res.count.must_equal(2)

      OMF::SFA::Resource::Lease.first(:uuid => l1.uuid).status.must_equal("accepted")
      OMF::SFA::Resource::Lease.first(:uuid => l2.uuid).status.must_equal("past")
      OMF::SFA::Resource::Lease.all.count.must_equal(2)

      node1 = OMF::SFA::Resource::Node.first({:name => 'node1', :account => @account})
      node1.wont_be_nil
      OMF::SFA::Resource::Node.first({:name => 'node2', :account => @account}).must_be_nil

      node1.leases.count.must_equal(1)
      node1.leases.first.must_equal(l1)

      authorizer.verify
    end

    it 'should attach a new lease without deleting the previous one' do
      authorizer = Minitest::Mock.new

      l1 = OMF::SFA::Resource::Lease.create({:name => @account.name, :account => @account,
                                            :valid_from => Time.parse('2013-01-08T19:00:00Z'),
                                            :valid_until => Time.parse('2013-01-08T20:00:00Z')})

      authorizer.expect(:account, @account)
      n = scheduler.create_resource({:urn => "urn:publicid:IDN+omf:nitos+node+node1"}, 'node', {}, authorizer)
      n.must_be_kind_of(OMF::SFA::Resource::Node)

      scheduler.lease_component(l1, n)
      n.reload
      n.leases.first.must_equal(l1)

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <ol:lease id="#{l1.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
        <ol:lease client_id="my_lease" valid_from="2013-01-08T21:00:00Z" valid_until="2013-01-08T22:00:00Z"/>
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
          <ol:lease_ref id_ref="#{l1.uuid}"/>
          <ol:lease_ref id_ref="my_lease"/>
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      2.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])}
      3.times {authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])}
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      5.times {authorizer.expect(:account, @account)}

      res = manager.update_resources_from_rspec(req.root, true, authorizer)

      res.count.must_equal(3)

      OMF::SFA::Resource::Lease.first(:uuid => l1.uuid).status.must_equal("accepted")

      node1 = OMF::SFA::Resource::Node.first({:name => 'node1', :account => @account})
      node1.wont_be_nil
      OMF::SFA::Resource::Node.first({:name => 'node2', :account => @account}).must_be_nil

      lease = node1.leases.select {|v| v.valid_from == Time.parse('2013-01-08T21:00:00Z')}.first
      lease.account.must_equal(@account)
      lease.valid_from.must_equal(Time.parse('2013-01-08T21:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T22:00:00Z'))
      lease.status.must_equal("accepted")

      node1.leases.count.must_equal(2)
      node1.leases.first.must_equal(l1)

      authorizer.verify
    end
  end # clean state flag

end
