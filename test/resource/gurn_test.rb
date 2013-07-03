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


describe GURN do

  before do
    init_dm
    GURN.clear_cache
  end

  it 'can create a GURN' do
    gurn = GURN.create('foo')
    gurn.must_be_kind_of(GURN)
    gurn.urn.must_equal("urn:publicid:IDN+#{Constants.default_domain}+foo")
    gurn.name.must_equal("#{Constants.default_domain}+foo")
  end

  it 'will parse a URN and return the corresponding GURN' do
    urn = "urn:publicid:IDN+domain+foo"
    gurn = GURN.create(urn)
    gurn.urn.must_equal(urn)
  end

  it 'will return an already created GURN' do
    gurn = GURN.create('foo')
    gurn2 = GURN.create('foo')
    gurn.must_equal(gurn2)
  end

  it 'will create a resource with a urn' do
    r = OResource.create(name: 'foo', urn: "urn:publicid:IDN+#{Constants.default_domain}+oresource+foo")
    r.urn.must_equal("urn:publicid:IDN+#{Constants.default_domain}+oresource+foo")
  end

  it 'will find a resource by its urn' do
    r = OResource.create(name: 'foo', urn: "urn:publicid:IDN+#{Constants.default_domain}+oresource+foo")
    r2 = OResource.first(urn: "urn:publicid:IDN+#{Constants.default_domain}+oresource+foo")
    r.must_equal(r2)
  end

  it 'will create and find a resource by its urn' do
    r = Node.create(interfaces: {name: 'if0'}, urn: 'urn:publicid:IDN+domain+node+foo', name: 'foo')
    r2 = Node.first(urn: "urn:publicid:IDN+domain+node+foo")
    r.must_equal(r2)
  end
end
