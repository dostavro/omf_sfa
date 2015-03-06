require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf_sfa'
require 'sequel'
require 'omf-sfa/am/am_manager'
require 'omf_common/load_yaml'
require 'omf-sfa/am/am-rpc/am_authorizer'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

OMF::Common::Loggable.init_log('am_manager', { :searchPath => File.join(File.dirname(__FILE__), 'am_manager') })
::Log4r::Logger.global.level = ::Log4r::OFF

class AMScheduler < MiniTest::Test
  def test_that_the_authorizer_can_create_an_account_name_from_urn
    urn = "urn:publicid:IDN+omf:testbed+slice+acc_name"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)
    acc_name = authorizer.create_account_name_from_urn(urn)
    
    assert_equal acc_name, "omf.testbed.acc_name"

    user_cert.verify
    cred[0].verify
  end

  def test_that_the_authorizer_can_create_an_account_name_from_a_big_urn
    urn = "urn:publicid:IDN+big.authority.domain.name:subauthority+slice+acc_name"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)
    acc_name = authorizer.create_account_name_from_urn(urn)

    assert_equal acc_name, "big.subauthority.acc_name"

    user_cert.verify
    cred[0].verify
  end

  def test_that_the_authorizer_can_create_an_account_name_from_a_big_urn_skipping_the_sub_authority
    urn = "urn:publicid:IDN+big.authority.domain.name:big.subauthority.name+slice+acc_name"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)
    acc_name = authorizer.create_account_name_from_urn(urn)

    assert_equal acc_name, "big.acc_name"

    user_cert.verify
    cred[0].verify
  end

  def test_that_the_authorizer_can_create_an_account_name_from_a_big_urn_skipping_domain_and_sub_authority
    urn = "urn:publicid:IDN+verybigauthoritydomain.name:big.subauthority.name+slice+big_acc_name"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)
    acc_name = authorizer.create_account_name_from_urn(urn)

    assert_equal acc_name, "big_acc_name"

    user_cert.verify
    cred[0].verify
  end

  def test_that_the_authorizer_can_create_an_account_name_from_just_the_slice_name
    urn = "urn:publicid:IDN+verybigauthoritydomain.name:bigsubauthorityname+slice+big_acc_name"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)
    acc_name = authorizer.create_account_name_from_urn(urn)

    assert_equal acc_name, "big_acc_name"

    user_cert.verify
    cred[0].verify
  end

  def test_that_the_authorizer_throws_an_exception_when_the_name_is_too_long
    urn = "urn:publicid:IDN+domain.name:subauthority+slice+enormous_account_name_should_throw_exception"

    user_cert = Minitest::Mock.new
    user_cert.expect :user_urn, "urn"

    cred = []
    cred[0] = Minitest::Mock.new
    cred[0].expect :user_urn, "urn"
    cred[0].expect :type, "slice"
    2.times {cred[0].expect :privilege?, true, ["*"]}

    authorizer = OMF::SFA::AM::RPC::AMAuthorizer.new(nil, user_cert, cred, nil, nil)

    assert_raises OMF::SFA::AM::FormatException do
      acc_name = authorizer.create_account_name_from_urn(urn)
    end

    user_cert.verify
    cred[0].verify
  end
end
