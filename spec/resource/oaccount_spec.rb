require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/resource/account'
require 'json'

include OMF::SFA::Resource

class R < OResource
end 

describe Account do
  before :all do
    init_dm
  end
  
  it 'can create an account' do
    a = Account.create()
  end
  
  it 'can create an account with a urn' do
    #a = Account.create(:urn => "urn:foo")
    a = Account.first_or_create(:urn => "urn:publicid:IDN+omf:test+account+1")
  end
  
  it 'can create an account with a urn if it doesnt exist yet' do
    a = Account.first_or_create(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+5d9d-4fb:127.0.0.1%3A8000")
  end

  it 'will return nil if no account found' do
    a = Account.first(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+test")
    a.should be_nil
  end

  it 'can create and find by urn' do

    init_dm

    a = Account.create(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+5d9d-4fb:127.0.0.1%3A8000")
    b = Account.create(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+__test__")
    
    aa = Account.first(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+5d9d-4fb:127.0.0.1%3A8000")
    bb = Account.first(:urn => "urn:publicid:IDN+geni:gpo:gcf+slice+__test__")

    a.should == aa
    b.should == bb
  end
  
  it 'can create and find by a name' do
    a = Account.create(:name => 'fooBar') 
    b = Account.first(:name => 'fooBar')
    a.should == b
  end
  
  it 'resources have a NULL default account' do
    r = R.create()
    r.account.should == nil
  end
  
  it 'resources can have an account' do
    a = Account.create()
    r = R.create(:account => a)
    r.reload.account.should == a
  end
  
  it 'resources can have an account which then can be nulled' do
    a = Account.create()
    r = R.create(:account => a)
    r.account = nil
    r.save
    r.reload.account.should == nil
  end
  
  it 'is is active when valid' do
    a = Account.create()
    #a.save
    a.reload
    a.active?.should == true
  end
  
  it 'is is no longer active after valid_until' do
    a = Account.create(:valid_until => Time.now - 1)
    a.active?.should == false
  end  

  it 'has Time oproperties' do
    a = Account.create(:valid_until => Time.now + 200)
    a.valid_until.should be_a_kind_of(Time)

    a.valid_until = Time.now + 100
    a.valid_until.should be_a_kind_of(Time)
  end

end
