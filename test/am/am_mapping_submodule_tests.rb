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

   def test_it_can_resolve_uuid_in_unbound_queries
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")
    t1 = Time.now

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)
    assert_equal ans[:resources].first[:uuid], n1.uuid.to_s
    assert_equal ans[:resources].first[:domain], 'domain1'
    assert_equal ans[:resources].first[:valid_from], t1.utc.to_s
    assert_equal ans[:resources].first[:valid_until], (t1 + 7200).utc.to_s

    authorizer.verify
  end

  def test_it_can_resolve_uuid_in_unbound_queries_for_more_than_one_resources
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1")
    t1 = Time.now

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        },
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    refute_empty ans[:resources][0][:uuid]
    assert_equal ans[:resources][0][:domain], 'domain1'
    assert_equal ans[:resources][0][:valid_from], t1.utc.to_s
    assert_equal ans[:resources][0][:valid_until], (t1 + 7200).utc.to_s
    refute_empty ans[:resources][1][:uuid]
    assert_equal ans[:resources][1][:domain], 'domain1'
    assert_equal ans[:resources][1][:valid_from], t1.utc.to_s
    assert_equal ans[:resources][1][:valid_until], (t1 + 7200).utc.to_s

    authorizer.verify
  end

  def test_it_can_resolve_urn_in_unbound_queries_for_more_than_one_resources
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", urn: "domain1:n1")
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1", urn: "domain1:n2")
    t1 = Time.now

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        },
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    refute_empty ans[:resources][0][:uuid]
    refute_empty ans[:resources][0][:urn]
    assert_equal ans[:resources][0][:domain], 'domain1'
    assert_equal ans[:resources][0][:valid_from], t1.utc.to_s
    assert_equal ans[:resources][0][:valid_until], (t1 + 7200).utc.to_s
    refute_empty ans[:resources][1][:uuid]
    refute_empty ans[:resources][1][:urn]
    assert_equal ans[:resources][1][:domain], 'domain1'
    assert_equal ans[:resources][1][:valid_from], t1.utc.to_s
    assert_equal ans[:resources][1][:valid_until], (t1 + 7200).utc.to_s

    authorizer.verify
  end

  def test_it_wont_give_the_same_resource_twice
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1")
    t1 = Time.now

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        },
        {
          type: "Node",
          domain: "domain1",
          valid_from:"#{t1}",
          valid_until:"#{t1 + 7200}"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    refute_equal ans[:resources][0][:uuid], ans[:resources][1][:uuid]

    authorizer.verify
  end

  def test_it_can_resolve_valid_from_and_valid_until_in_unbound_queries
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources].first[:uuid], n1.uuid.to_s
    assert_equal ans[:resources].first[:domain], 'domain1'
    refute_nil ans[:resources].first[:valid_from]
    refute_nil ans[:resources].first[:valid_until]

    authorizer.verify
  end

  def test_it_can_resolve_valid_from_and_valid_until_from_duration_in_unbound_queries
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          duration: 100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources].first[:uuid], n1.uuid.to_s
    assert_equal ans[:resources].first[:domain], 'domain1'
    refute_nil ans[:resources].first[:valid_from]
    refute_nil ans[:resources].first[:valid_until]

    authorizer.verify
  end

  def test_it_can_resolve_exclusive_in_unbound_queries
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          duration: 100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources].first[:uuid], n1.uuid.to_s
    assert_equal ans[:resources].first[:domain], 'domain1'
    refute_nil ans[:resources].first[:exclusive]

    authorizer.verify
  end

  def test_it_can_resolve_exclusive_in_unbound_queries_based_on_already_given_exclusive
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n3 = OMF::SFA::Model::Node.create(name: 'n3', account: @scheduler.get_nil_account, domain: "domain2", exclusive: false)
    t1 = Time.now

    q = {
      resources:[
        {
          type: "Node",
          exclusive:true,
          duration:100
        },
        {
          type: "Node",
          duration:100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources][0][:domain], 'domain1'
    assert_equal ans[:resources][0][:exclusive], true
    assert_equal ans[:resources][1][:domain], 'domain1'
    assert_equal ans[:resources][1][:exclusive], true

    authorizer.verify
  end

  def test_it_can_resolve_domain_in_unbound_queries
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n3 = OMF::SFA::Model::Node.create(name: 'n3', account: @scheduler.get_nil_account, domain: "domain2", exclusive: true)

    q = {
      resources:[
        {
          type: "Node"        }
      ]
    }
    authorizer = MiniTest::Mock.new
    12.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources].first[:domain], 'domain1'

    authorizer.verify
  end

  def test_it_can_resolve_domain_in_unbound_queries_based_on_already_given_domains
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    n3 = OMF::SFA::Model::Node.create(name: 'n3', account: @scheduler.get_nil_account, domain: "domain2", exclusive: true)

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1"
        },
        {
          type: "Node"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    14.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources][0][:domain], 'domain1'
    assert_equal ans[:resources][1][:domain], 'domain1'

    authorizer.verify
  end

  def test_it_can_resolve_both_a_channel_and_a_node_in_the_same_request
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)
    c1 = OMF::SFA::Model::Channel.create(name: 'c2', account: @scheduler.get_nil_account, domain: "domain1", exclusive: true)

    q = {
      resources:[
        {
          type: "Node"
        },
        {
          type: "Channel"
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    13.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    ans = @scheduler.resolve_query(q, manager, authorizer)

    assert_equal ans[:resources][0][:uuid], n1.uuid.to_s
    assert_equal ans[:resources][1][:uuid], c1.uuid.to_s

    authorizer.verify
  end

  def test_it_throws_exception_when_there_are_no_available_resources
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account:  @scheduler.get_nil_account, domain: "domain1")

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain1",
          duration: 100
        },
        {
          type: "Node",
          domain: "domain1",
          duration: 100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    4.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    assert_raises OMF::SFA::AM::UnavailableResourceException do
      ans = @scheduler.resolve_query(q, manager, authorizer)        
    end

    authorizer.verify
  end

  def test_it_throws_exception_when_there_are_no_available_resources_matching_the_description
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")

    q = {
      resources:[
        {
          type: "Node",
          domain: "domain2",
          duration: 100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    3.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    assert_raises OMF::SFA::AM::UnknownResourceException do
      ans = @scheduler.resolve_query(q, manager, authorizer)
    end

    authorizer.verify
  end

  def test_it_throws_exception_when_there_are_no_available_resources_on_the_same_domain
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1")
    n2 = OMF::SFA::Model::Node.create(name: 'n2', account: @scheduler.get_nil_account, domain: "domain2")

    q = {
      resources:[
        {
          type: "Node",
          duration: 100
        },
        {
          type: "Node",
          duration: 100
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    8.times {authorizer.expect(:can_view_resource?, true, [OMF::SFA::Model::Resource])}
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    assert_raises OMF::SFA::AM::UnavailableResourceException do
      ans = @scheduler.resolve_query(q, manager, authorizer)        
    end

    authorizer.verify
  end

  def test_it_throws_exception_when_there_are_no_available_resources_with_the_asked_exclusiveness
    n1 = OMF::SFA::Model::Node.create(name: 'n1', account: @scheduler.get_nil_account, domain: "domain1", exclusive: false)

    q = {
      resources:[
        {
          type: "Node",
          exclusive: true
        }
      ]
    }
    authorizer = MiniTest::Mock.new
    
    manager = OMF::SFA::AM::AMManager.new(@scheduler)

    assert_raises OMF::SFA::AM::UnknownResourceException do
      ans = @scheduler.resolve_query(q, manager, authorizer)   
    end

    authorizer.verify
  end
end