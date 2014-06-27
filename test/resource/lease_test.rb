require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
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



describe 'Lease' do

  valid_from =Time.parse("2013-04-01 12:00:00 +0300")
  valid_until = Time.parse("2013-04-01 13:00:00 +0300")

  init_dm

  before do
    DataMapper.auto_migrate! # reset database before each example
  end

  it 'will create a lease' do
    l = OMF::SFA::Resource::Lease.create(:name => 'l1')
    l.must_be_kind_of(OMF::SFA::Resource::Lease)
  end

  it 'will create a lease with oproperties' do
    l = OMF::SFA::Resource::Lease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})
    l.name.must_equal('l1')
    l.valid_from.must_equal(valid_from)
    l.valid_until.must_equal(valid_until)
  end

  it 'will find a lease by its oproperties' do
    l1 = OMF::SFA::Resource::Lease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l2 = OMF::SFA::Resource::Lease.first({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l1.must_equal(l2)
  end

  it 'will find all the leases that start in the future' do
    skip # it would be good to extend Datamapper in order to enable this feature
    t1 = Time.now + 3600
    t2 = t1 + 3600
    l1 = OMF::SFA::Resource::Lease.create(name: 'l1', valid_from: t1, valid_until: t2)
    OMF::SFA::Resource::Lease.create(name: 'l2', valid_from: Time.now, valid_until: Time.now + 3600)

    leases = Lease.all(:valid_from.gt => Time.now)
    leases.must_equal([l1])
  end

  it "will set the 'status' oproperty" do
    l1 = OMF::SFA::Resource::Lease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l1.status.must_equal("pending")
    l1.status = "accepted"

    l1.status.must_equal("accepted")
    l1.cancelled?.must_equal false
    l1.accepted?.must_equal true
  end

  it "can have time oproperties" do
    l = OMF::SFA::Resource::Lease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l.valid_from.must_be_kind_of(Time)
    l.valid_until.must_be_kind_of(Time)
  end

  it "can lease with valid_until/valid_from as String" do 
    v_f = "2013-04-01 12:00:00 +0300"
    v_u = "2013-04-01 13:00:00 +0300"

    l = OMF::SFA::Resource::Lease.create({:name => 'l1', :valid_from => v_f, :valid_until => v_u})
    l.valid_from.must_be_kind_of(Time)
    l.valid_until.must_be_kind_of(Time)
  end
end
