require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'

require 'dm-migrations'
require 'omf-sfa/resource'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/am/am_manager'
require 'omf_common/load_yaml'


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

def init_logger
  OMF::Common::Loggable.init_log 'am_rest', :searchPath => File.join(File.dirname(__FILE__), 'am_rest')
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe User do
  before do
    init_dm
    init_logger
  end


  it 'can create a User' do
    User.create()
  end

  it 'can have many Projects' do
    u = User.create(name: 'u1')
    p1 = Project.create(name: 'p1')
    p2 = Project.create(name: 'p2')

    u.projects << p1
    u.save
    u.projects.must_equal([p1])

    u.projects << p2
    u.save
    u.projects.must_equal([p1, p2])
  end

  it "doesn't contain duplicate projects" do
    u = User.create(name: 'u1')
    p1 = Project.create(name: 'p1')
    p2 = Project.create(name: 'p2')

    u.projects << p1
    u.projects << p2
    u.save

    u.add_project(p1)
    u.projects.must_equal([p1, p2])

    p3 = Project.create(name: 'p3')
    u.add_project(p3)
    u.projects.must_equal([p1, p2, p3])
  end

  it "can return all accounts of a user" do 
    u = User.create(name: 'u1')
    a1 = Account.create(name: 'a1')
    a2 = Account.create(name: 'a2')
    p1 = Project.create(name: 'p1', account: a1)
    p2 = Project.create(name: 'p2', account: a2)
    u.add_project p1
    u.add_project p2
    u.save
    a1.save
    a2.save
    p1.save
    p2.save

    acs = u.get_all_accounts

    acs.size.must_equal 2
    acs[0].name.must_equal 'a1'
    acs[1].name.must_equal 'a2'
  end

   it "can return the first account of a user" do 
    u = User.create(name: 'u1')
    a1 = Account.create(name: 'a1')
    a2 = Account.create(name: 'a2')
    p1 = Project.create(name: 'p1', account: a1)
    p2 = Project.create(name: 'p2', account: a2)
    u.add_project p1
    u.add_project p2
    u.save
    a1.save
    a2.save
    p1.save
    p2.save

    ac = u.get_first_account

    ac.must_be_instance_of OMF::SFA::Resource::Account
    ac.name.must_equal 'a1'
  end

  it "must return the account with the same name as the user" do 
    u = User.create(name: 'u1')
    a1 = Account.create(name: 'u1')
    a2 = Account.create(name: 'a2')
    p1 = Project.create(name: 'p1', account: a1)
    p2 = Project.create(name: 'p2', account: a2)
    u.add_project p1
    u.add_project p2
    u.save
    a1.save
    a2.save
    p1.save
    p2.save

    ac = u.get_first_account

    ac.must_be_instance_of OMF::SFA::Resource::Account
    ac.name.must_equal 'u1'
  end

  it "will respond if the user has the nill account" do 
    manager = OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new)
    u = User.create(name: 'u1')
    a1 = Account.create(name: 'u1')
    p1 = Project.create(name: 'p1', account: a1)
    p2 = Project.create(name: 'p2', account: manager.get_scheduler.get_nil_account)
    u.add_project p1
    u.add_project p2
    u.save
    a1.save
    p1.save
    p2.save

    res = u.has_nil_account?(manager)

    res.must_equal true
  end
end
