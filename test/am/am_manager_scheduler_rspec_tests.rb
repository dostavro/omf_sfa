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

  # let (:scheduler) do
  #   scheduler = Class.new do
  #     def self.get_nil_account
  #       nil
  #     end
  #     def self.create_resource(resource_descr, type_to_create, oproperties, auth)
  #       resource_descr[:resource_type] = type_to_create
  #       #resource_descr[:account] = auth.account
  #       type = type_to_create.camelize
  #       resource = eval("OMF::SFA::Resource::#{type}").create(resource_descr)
  #       if type_to_create.downcase.eql?('lease')
  #         resource.valid_from = oproperties[:valid_from]
  #         resource.valid_until = oproperties[:valid_until]
  #         resource.save
  #       end
  #       return resource
  #     end
  #     def self.release_resource(resource, authorizer)
  #       resource.destroy
  #     end
  #     def self.lease_component(lease, component)
  #       component.leases << lease
  #       component.save
  #     end
  #   end
  #   scheduler
  # end

  let (:scheduler) { AMScheduler.new }
  let (:manager) { AMManager.new(scheduler) }


  describe 'resource creation' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'a'})
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

      2.times {authorizer.expect(:account, @account)}
      resources = manager.update_resources_from_rspec(request.root, true, authorizer)
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

      4.times {authorizer.expect(:account, @account)}
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      resources = manager.update_resources_from_rspec(request.root, true, authorizer)
      resources.size.must_equal(1)
      node = resources.first

      node.component_name.must_equal("node1")
      node.client_id.must_equal("my_node")

      authorizer.verify
    end

    it "won't create a node that doesn't exist" do
      authorizer = Minitest::Mock.new

      rspec = %{
      <?xml version="1.0" ?>
      <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
        <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" exclusive="true">
        </node>
      </rspec>
      }
      request = Nokogiri.XML(rspec)

      4.times {authorizer.expect(:account, @account)}
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      resources = manager.update_resources_from_rspec(request.root, true, authorizer)
      resources.size.must_equal(1)
      node = resources.first

      node.component_name.must_equal("node1")

      authorizer.verify
    end
  end

  describe 'nodes and leases' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'a'})
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

      node = r.last
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')
      node.client_id.must_equal('my_node')

      a = node.account
      a.name.must_equal('a')

      lease = r.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.name.must_equal(a.name)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)
      lease.client_id.must_equal('l1')

      authorizer.verify
    end

    it 'will create a node with an already known lease attached to it' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.new({:name => @account.name})
      valid_from = Time.parse('2013-01-08T19:00:00Z')
      valid_until = Time.parse('2013-01-08T20:00:00Z')
      l.valid_from = valid_from
      l.valid_until = valid_until
      l.save
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

      node = r.last
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.must_equal(l)
      lease.name.must_equal(a.name)
      lease.valid_from.must_equal(valid_from)
      lease.valid_until.must_equal(valid_until)
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end

    it 'will attach an additional lease to a node 123' do
      authorizer = Minitest::Mock.new

      l = OMF::SFA::Resource::Lease.new({:name => @account.name})
      valid_from = Time.parse('2013-01-08T19:00:00Z')
      valid_until = Time.parse('2013-01-08T20:00:00Z')
      l.valid_from = valid_from
      l.valid_until = valid_until
      l.save

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

      node = r.last
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.must_equal(@account)

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.name.must_equal(a.name)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      lease2 = node.leases[1]
      lease2.must_be_kind_of(OMF::SFA::Resource::Lease)
      lease.name.must_equal(a.name)
      lease2.valid_from.must_equal(Time.parse('2013-01-08T12:00:00Z'))
      lease2.valid_until.must_equal(Time.parse('2013-01-08T14:00:00Z'))
      lease2.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      OMF::SFA::Resource::Lease.count.must_equal(2)

      authorizer.verify
    end

    #it 'will create a node with an already known lease attached to it (included in rspecs)' do
    #  authorizer = Minitest::Mock.new
    #  l = OMF::SFA::Resource::Lease.new({ :name => @account.name })
    #  l.valid_from = '2013-01-08T19:00:00Z'
    #  l.valid_until = '2013-01-08T20:00:00Z'
    #  l.save

    #  rspec = %{
    #  <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
    #    <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" component_manager_id="urn:publicid:IDN+openlab+authority+am">
    #      <ol:lease uuid="#{l.uuid}" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T20:00:00Z"/>
    #    </node>
    #  </rspec>
    #  }
    #  req = Nokogiri.XML(rspec)

    #  authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
    #  authorizer.expect(:can_modify_lease?, true, [OMF::SFA::Resource::Lease])
    #  authorizer.expect(:can_create_resource?, true, [Hash, String])
    #  authorizer.expect(:account, @account)

    #  r = manager.update_resources_from_rspec(req.root, false, authorizer)

    #  node = r.first
    #  node.must_be_kind_of(OMF::SFA::Resource::Node)
    #  node.name.must_equal('node1')
    #  node.resource_type.must_equal('node')

    #  a = node.account
    #  a.name.must_equal('a')

    #  lease = node.leases.first
    #  lease.must_be_kind_of(OMF::SFA::Resource::Lease)
    #  lease.name.must_equal(a.name)
    #  lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
    #  lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
    #  lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

    #  authorizer.verify
    #end

    # it 'will attach 2 leases(1 new and 1 old) to 2 nodes' do
    #   authorizer = Minitest::Mock.new
    #   l1 = OMF::SFA::Resource::Lease.new({ :name => @account.name})
    #   l1.valid_from = Time.parse('2013-01-08T19:00:00Z')
    #   l1.valid_until = Time.parse('2013-01-08T20:00:00Z')
    #   l1.save

    #   rspec = %{
    #   <?xml version="1.0" ?>
    #   <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
    #     <ol:lease id="#{l1.uuid}" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
    #     <ol:lease client_id="l2" valid_from="2013-01-08T12:00:00Z" valid_until="2013-01-08T14:00:00Z"/>
    #     <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="omf" exclusive="true">
    #       <ol:lease_ref id_ref="#{l1.uuid}"/>
    #     </node>
    #     <node component_id="urn:publicid:IDN+omf:nitos+node+node2" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node2" client_id="omf" exclusive="true">
    #       <ol:lease_ref id_ref="l2"/>
    #     </node>
    #   </rspec>
    #   }
    #   req = Nokogiri.XML(rspec)

    #   3.times { authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease]) }
    #   3.times { authorizer.expect(:can_create_resource?, true, [Hash, String]) }
    #   4.times {authorizer.expect(:account, @account)}

    #   r = manager.update_resources_from_rspec(req.root, false, authorizer)

    #   node = r.first
    #   node.must_be_kind_of(OMF::SFA::Resource::Node)
    #   node.name.must_equal('node1')
    #   node.resource_type.must_equal('node')

    #   a = node.account
    #   a.name.must_equal('a')

    #   lease = node.leases.first
    #   lease.must_be_kind_of(OMF::SFA::Resource::Lease)
    #   lease.name.must_equal(a.name)
    #   lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
    #   lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
    #   lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

    #   node = r[1]
    #   node.must_be_kind_of(OMF::SFA::Resource::Node)
    #   node.name.must_equal('node2')
    #   node.resource_type.must_equal('node')

    #   a = node.account
    #   a.name.must_equal('a')

    #   lease = node.leases.first
    #   lease.must_be_kind_of(OMF::SFA::Resource::Lease)
    #   lease.name.must_equal(a.name)
    #   lease.valid_from.must_equal(Time.parse('2013-01-08T12:00:00Z'))
    #   lease.valid_until.must_equal(Time.parse('2013-01-08T14:00:00Z'))
    #   lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

    #   authorizer.verify
    # end
  end # nodes and leases

  describe 'channels and leases' do

    before do
      DataMapper.auto_migrate! # reset database
      @account = OMF::SFA::Resource::Account.create({:name => 'a'})
      r = OMF::SFA::Resource::Channel.create({:urn => "urn:publicid:IDN+omf:nitos+channel+9"})
      manager.manage_resource(r)
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

      2.times { authorizer.expect(:can_create_resource?, true, [Hash, String]) }
      4.times {authorizer.expect(:account, @account)}

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      channel = r.last
      channel.must_be_kind_of(OMF::SFA::Resource::Channel)
      channel.name.must_equal('9')
      channel.resource_type.must_equal('channel')

      a = channel.account
      a.name.must_equal(@account.name)

      lease = channel.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::Lease)
      #lease.name.must_equal(a.name)
      lease.valid_from.must_equal(Time.parse('2013-01-08T19:00:00Z'))
      lease.valid_until.must_equal(Time.parse('2013-01-08T20:00:00Z'))
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Channel)

      authorizer.verify
    end

    #it 'will reserve a channel and a node' do
    #  authorizer = Minitest::Mock.new
    #  rspec = %{
    #  <?xml version="1.0" ?>
    #  <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
    #    <ol:lease client_id="l1" valid_from="2013-01-08T19:00:00Z" valid_until="2013-01-08T20:00:00Z"/>
    #    <ol:channel client_id="my_channel" component_id="urn:publicid:IDN+omf:nitos+channel+9" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="9" frequency="2.452GHz">
    #      <ol:lease_ref id_ref="l1"/>
    #    </ol:channel>
    #    <node component_id="urn:publicid:IDN+omf:nitos+node+node1" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node1" client_id="my_node" exclusive="true">
    #      <ol:lease_ref id_ref="l1"/>
    #    </node>
    #  </rspec>
    #  }
    #  req = Nokogiri.XML(rspec)
    #end
  end # channel and leases

  #describe 'clean state flag' do

  #  it 'will create a new node and lease without deleting the previous records' do
  #    authorizer = Minitest::Mock.new
  #    l = OMF::SFA::Resource::Lease.create({ :name => @account.name, :account => @account})
  #    l.valid_from = '2013-01-08T19:00:00Z'
  #    l.valid_until = '2013-01-08T20:00:00Z'
  #    l.save

  #    r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => @account})
  #    r.leases << l
  #    r.save

  #    rspec = %{
  #    <?xml version="1.0" ?>
  #    <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
  #      <ol:lease id="l1" valid_from="2013-01-08T12:00:00Z" valid_until="2013-01-08T14:00:00Z"/>
  #      <node component_id="urn:publicid:IDN+omf:nitos+node+node2" component_manager_id="urn:publicid:IDN+omf:nitos+authority+am" component_name="node2" client_id="omf" exclusive="true">
  #        <ol:lease_ref id_ref="l1"/>
  #      </node>
  #    </rspec>
  #    }
  #    req = Nokogiri.XML(rspec)

  #    authorizer.expect(:can_create_resource?, true, [Hash, String])
  #    authorizer.expect(:can_create_resource?, true, [Hash, String])
  #    2.times { authorizer.expect(:account, @account) }

  #    res = manager.update_resources_from_rspec(req.root, false, authorizer)

  #    res.length.must_equal 1
  #    r1 = res.first
  #    r1.name.must_equal('node2')
  #    r1.leases.first.name.must_equal(@account.name)

  #    node = OMF::SFA::Resource::Node.first(:name => 'node1')
  #    node.wont_be_nil
  #    node.leases.first.wont_be_nil

  #    authorizer.verify
  #  end

  #  it 'will unlink a node from a lease and release both' do
  #    authorizer = Minitest::Mock.new
  #    l = OMF::SFA::Resource::Lease.create({:name => 'l1', :account => @account})
  #    l.valid_from = '2013-01-08T19:00:00Z'
  #    l.valid_until = '2013-01-08T20:00:00Z'
  #    l.save

  #    r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => @account})
  #    r.leases << l
  #    r.save

  #    rspec = %{
  #    <?xml version="1.0" ?>
  #    <rspec type="request" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/sfa/rspec/1/request-reservation.xsd">
  #    </rspec>
  #    }

  #    req = Nokogiri.XML(rspec)

  #    authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
  #    authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
  #    authorizer.expect(:can_release_lease?, true, [OMF::SFA::Resource::Lease])
  #    authorizer.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
  #    2.times {authorizer.expect(:account, @account)}

  #    r = manager.update_resources_from_rspec(req.root, true, authorizer)
  #    r.must_be_empty

  #    OMF::SFA::Resource::Node.first(:name => 'node1').must_be_nil

  #    l.reload
  #    l.components.first.must_be_nil

  #    OMF::SFA::Resource::Lease.first(:name => 'l1').wont_be_nil
  #    OMF::SFA::Resource::Lease.first(:name => 'l1').status.must_equal("cancelled")

  #    authorizer.verify
  #  end

  #  #it 'will release a node and a lease' do
  #  #  authorizer = Minitest::Mock.new
  #  #  l = OMF::SFA::Resource::Lease.create({:name => 'l1', :account => @account})
  #  #  l.valid_from = '2013-01-08T19:00:00Z'
  #  #  l.valid_until = '2013-01-08T20:00:00Z'
  #  #  l.save

  #  #  r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => @account})
  #  #  r.leases << l
  #  #  r.save

  #  #  l.components.first.must_equal(r)

  #  #  rspec = %{
  #  #  <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
  #  #  </rspec>
  #  #  }
  #  #  req = Nokogiri.XML(rspec)

  #  #  authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
  #  #  authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::Lease])
  #  #  authorizer.expect(:can_release_lease?, true, [OMF::SFA::Resource::Lease])
  #  #  authorizer.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
  #  #  authorizer.expect(:account, @account)
  #  #  authorizer.expect(:account, @account)

  #  #  r = manager.update_resources_from_rspec(req.root, true, authorizer)

  #  #  r.must_be_empty
  #  #  OMF::SFA::Resource::Node.first(:name => 'node1').must_be_nil
  #  #  OMF::SFA::Resource::Lease.first(:name => 'l1').status.must_equal('cancelled')
  #  #
  #  #  authorizer.verify
  #  #end
  #end # clean state flag

end
