require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'
require 'omf-sfa/am/am_policies'
require 'omf_common/load_yaml'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

OMF::Common::Loggable.init_log('am_policies', { :searchPath => File.join(File.dirname(__FILE__), 'am_manager') })
::Log4r::Logger.global.level = ::Log4r::OFF

# Must use this class as the base class for your tests
class AMPolicies< MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def before_setup
  end

  def test_it_will_always_return_true_when_disabled
    opts = {policies: {enabled: false}}
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    assert_equal am_policies.valid?(nil,nil), true
    assert_equal am_policies.validate(nil,nil), true
  end

  def test_valid_false_because_lease_exceeds_max_minutes_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60 * 3
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac)

    assert_equal am_policies.valid?(l1,nil), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, nil)
    end
  end

  def test_valid_false_because_lease_exceeds_max_resources_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac)
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)
    l1.components << p1
    l1.components << n1
    l1.components << p2
    l1.components << n2
    l1.components << p3
    l1.components << n3

    assert_equal am_policies.valid?(l1,nil), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, nil)
    end
  end

  def test_valid_false_because_lease_exceeds_max_resources_policy_on_new_component
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac)
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)
    l1.components << p1
    l1.components << n1
    l1.components << p2
    l1.components << n2

    assert_equal am_policies.valid?(l1, n3), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, n3)
    end
  end

  def test_valid_false_because_lease_exceeds_max_minutes_policy_overall
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 90
    t3 = t2 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')

    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t2, valid_until: t3, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l2, nil), false
    assert_raises OMF::SFA::AM::MaxMinutesQuotaExceededException do
      am_policies.validate(l2, nil)
    end
  end

  def test_valid_false_because_lease_exceeds_max_resources_policy_overall
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 4,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60
    t3 = t2 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)
    l1.add_component p1
    l1.add_component n1
    l1.add_component p2
    l1.add_component n2

    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t2, valid_until: t3, account: ac, status: 'pending')
    l2.add_component p3
    l2.add_component n3

    assert_equal am_policies.valid?(l2, nil), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l2, nil)
    end
  end

  def test_valid_false_because_lease_exceeds_max_resources_policy_overall_with_new_component
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 4,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60
    t3 = t2 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)
    l1.add_component p1
    l1.add_component n1
    l1.add_component p2
    l1.add_component n2

    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t2, valid_until: t3, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l2, n3), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l2, n3)
    end
  end

  def test_valid_true_for_max_minutes_policy_in_mutliple_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 3,
                      max_resources: 3
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:58:00 UTC")
    t2 = t1 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l1, nil), true
    assert_equal am_policies.validate(l1, nil), true
  end

  def test_valid_false_for_max_minutes_policy_in_mutliple_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 3
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:58:00 UTC")
    t2 = t1 + 240
    t3 = Time.parse("2001-01-01 23:58:30 UTC")
    t4 = t3 + 210
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l2, nil), false
    assert_raises OMF::SFA::AM::MaxMinutesQuotaExceededException do
      am_policies.validate(l2, nil)
    end
  end

  def test_valid_false_for_max_minutes_policy_in_three_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 2,
                      max_resources: 3
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:58:00 UTC")
    t2 = t1 + 1.days + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l1, nil), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, nil)
    end
  end

  def test_valid_true_for_max_resources_policy_in_three_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:58:00 UTC")
    t2 = t1 + 1.days + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1

    assert_equal am_policies.valid?(l1, nil), true
    assert_equal am_policies.validate(l1, nil), true
  end

  def test_valid_false_for_max_resources_policy_in_three_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-02 23:58:00 UTC")
    t2 = t1 + 60
    t3 = Time.parse("2001-01-01 23:58:00 UTC")
    t4 = t3 + 1.days + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'pending')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2

    assert_equal am_policies.valid?(l2, nil), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l2, nil)
    end
  end

  def test_valid_false_for_max_resources_policy_in_mutliple_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l3, nil)
    end
  end

  def test_valid_false_for_max_resources_policy_in_mutliple_days_with_component
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l3, n3), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l3, n3)
    end
  end

  def test_valid_false_for_max_resources_policy_in_mutliple_days_with_component
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l3, n3), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l3, n3)
    end
  end

  def test_valid_true_for_max_resources_policy_in_mutliple_days_with_component
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')

    assert_equal am_policies.valid?(l3, n3), true
    assert_equal am_policies.validate(l3, n3), true
  end

  def test_valid_true_for_max_resources_policy_in_mutliple_days
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), true
    assert_equal am_policies.validate(l3, nil), true
  end

  def test_valid_true_for_infinite_max_resources_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 10,
                      max_resources: -1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), true
    assert_equal am_policies.validate(l3, nil), true
  end

  def test_valid_true_for_infinite_max_resources_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: 10
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), true
    assert_equal am_policies.validate(l3, nil), true
  end

  def test_valid_false_for_infinite_max_resources_policy_but_finite_max_minutes
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 3,
                      max_resources: -1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), false
    assert_raises OMF::SFA::AM::MaxMinutesQuotaExceededException do
      am_policies.validate(l3, nil)
    end
  end

  def test_valid_false_for_infinite_max_minutes_policy_but_finite_max_resources
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), false
    assert_raises OMF::SFA::AM::MaxResourcesQuotaExceededException do
      am_policies.validate(l3, nil)
    end
  end

  def test_valid_true_for_urn_specific_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: 0,
                      max_resources: 0
                    }
                  }
                ],
                policies_per_urn:[
                  {
                    urn: 'urn:publicid:IDN+omf:testdomain+slice+account1',
                    quota: {
                      max_minutes: -1,
                      max_resources: -1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.parse("2001-01-01 23:57:00 UTC")
    t2 = t1 + 150
    t3 = Time.parse("2001-01-02 00:00:00 UTC")
    t4 = t3 + 150
    t5 = Time.parse("2001-01-01 23:58:00 UTC")
    t6 = t5 + 240
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac, status: 'accepted')
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    l1.add_component p1
    l1.add_component n1
    l2 = OMF::SFA::Model::Lease.create(name: 'lease2', valid_from: t3, valid_until: t4, account: ac, status: 'accepted')
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    l2.add_component p2
    l2.add_component n2
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)

    l3 = OMF::SFA::Model::Lease.create(name: 'lease3', valid_from: t5, valid_until: t6, account: ac, status: 'pending')
    l3.add_component p3
    l3.add_component n3

    assert_equal am_policies.valid?(l3, nil), true
    assert_equal am_policies.validate(l3, nil), true
  end

  def test_valid_false_for_max_minutes_urn_specific_policy
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: -1
                    }
                  }
                ],
                policies_per_urn:[
                  {
                    urn: 'urn:publicid:IDN+omf:testdomain+slice+account1',
                    quota: {
                      max_minutes: 1,
                      max_resources: 1
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60 * 3
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac)

    assert_equal am_policies.valid?(l1,nil), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, nil)
    end
  end

  def test_valid_false_for_max_resources_urn_specific_policy_xxx
    opts =  {
              policies: {
                enabled: true,
                policies_per_domain:[
                  {
                    domain: 'omf:testdomain',
                    quota: {
                      max_minutes: -1,
                      max_resources: -1
                    }
                  }
                ],
                policies_per_urn:[
                  {
                    urn: 'urn:publicid:IDN+omf:testdomain+slice+account1',
                    quota: {
                      max_minutes: -1,
                      max_resources: 2
                    }
                  }
                ]
              }
            }
    am_policies = OMF::SFA::AM::AMPolicies.new(opts)
    
    t1 = Time.now
    t2 = t1 + 60
    nil_ac = OMF::SFA::Model::Account.create(name: 'nil_account', urn: "urn:publicid:IDN+omf:testdomain+slice+nil_account")
    ac = OMF::SFA::Model::Account.create(name: 'account1', urn: "urn:publicid:IDN+omf:testdomain+slice+account1")
    l1 = OMF::SFA::Model::Lease.create(name: 'lease1', valid_from: t1, valid_until: t2, account: ac)
    p1 = OMF::SFA::Model::Node.create(name: 'node1', account: nil_ac)
    n1 = OMF::SFA::Model::Node.create(name: 'node1', account: ac, parent_id: p1.id)
    p2 = OMF::SFA::Model::Node.create(name: 'node2', account: nil_ac)
    n2 = OMF::SFA::Model::Node.create(name: 'node2', account: ac, parent_id: p2.id)
    p3 = OMF::SFA::Model::Node.create(name: 'node3', account: nil_ac)
    n3 = OMF::SFA::Model::Node.create(name: 'node3', account: ac, parent_id: p3.id)
    l1.components << p1
    l1.components << n1
    l1.components << p2
    l1.components << n2
    l1.components << p3
    l1.components << n3

    assert_equal am_policies.valid?(l1,nil), false
    assert_raises OMF::SFA::AM::QuotaExceededException do
      am_policies.validate(l1, nil)
    end
  end
end
