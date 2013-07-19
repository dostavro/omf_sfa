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

describe User do
  before do
    init_dm
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
end
