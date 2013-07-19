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

describe Project do
  before do
    init_dm
  end


  it 'can create a Project' do
    Project.create()
  end

  it 'has 1 account' do
    a = Account.create(name: 'a1')
    p = Project.create(account: a)

    p.account.must_equal(a)
    a.project.must_equal(p)
  end

  it 'can have multiple users' do
    p = Project.create(name: 'p1')
    u1 = User.create(name: 'u1')
    u2 = User.create(name: 'u2')

    p.users << u1
    p.save
    p.users.must_equal([u1])
    u1.projects.must_equal([p])

    p.users << u2
    p.save
    p.users.must_equal([u1, u2])
    u2.projects.must_equal([p])
  end

  it "doesn't contain duplicate users" do
    p = Project.create(name: 'p1')
    u1 = User.create(name: 'u1')
    u2 = User.create(name: 'u2')

    p.users << u1
    p.users << u2
    p.save

    p.add_user(u1)
    p.users.must_equal([u1, u2])

    u3 = User.create(name: 'u3')
    p.add_user(u3)
    p.users.must_equal([u1, u2, u3])
  end
end
