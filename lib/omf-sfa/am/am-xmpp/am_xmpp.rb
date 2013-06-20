require 'omf_rc'
require 'omf_common'
require 'omf-sfa/am/am-xmpp/am_authorizer'

module OmfRc::ResourceProxy::AMController
  include OmfRc::ResourceProxyDSL

  register_proxy :am_controller

  hook :before_ready do |resource|
    #logger.debug "creation opts #{resource.creation_opts}"
    @manager = resource.creation_opts[:manager]
  end

  request :resources do |resource, cert|
    authorizer = OMF::SFA::AM::XMPP::AMAuthorizer.create_for_xmpp_request(cert.to_x509, @manager)
    resources = @manager.find_all_resources_for_account(@manager._get_nil_account, authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(resources)
  end

  request :components do |resource, cert|
    authorizer = OMF::SFA::AM::XMPP::AMAuthorizer.create_for_xmpp_request(cert.to_x509, @manager)
    components = @manager.find_all_components_for_account(@manager._get_nil_account, authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(components)
  end

  request :leases do |resource, cert|
    authorizer = OMF::SFA::AM::XMPP::AMAuthorizer.create_for_xmpp_request(cert.to_x509, @manager)
    leases = @manager.find_all_leases(authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(leases)
  end

  request :slices do |resource, cert|
    authorizer = OMF::SFA::AM::XMPP::AMAuthorizer.create_for_xmpp_request(cert.to_x509, @manager)
    accounts = @manager.find_all_accounts(authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(accounts)
  end


  #configure :resource do |resource, value, cert|
  #end


  # We override the create method of AbstractResource
  #def create(type, opts = {}, creation_opts = {}, &creation_callback)
  #  response = {}
  #  response[:res_id] = self.resource_address
  #  self.inform(:creation_ok, response)
  #end

  def handle_create_message(message, obj, response)
    response[:foo] = 'bar'
    self.inform(:creation_ok, response)
  end

  #def handle_release_message(message, obj, response)
  #  puts "I'm not releasing anything"
  #end
end


module OMF::SFA::AM::XMPP

  class AMController
    include OMF::Common::Loggable


    def initialize(opts)
      @manager = opts[:manager]

      EM.next_tick do
        OmfCommon.comm.on_connected do |comm|
          auth = opts[:xmpp][:auth]

          entity_cert = File.expand_path(auth[:entity_cert])
          entity_key = File.expand_path(auth[:entity_key])
          @cert = OmfCommon::Auth::Certificate.create_from_x509(File.read(entity_cert), File.read(entity_key))
          OmfCommon::Auth::CertificateStore.instance.register(@cert, OmfCommon.comm.local_topic.address)

          trusted_roots = File.expand_path(auth[:root_cert_dir])
          OmfCommon::Auth::CertificateStore.instance.register_default_certs(trusted_roots)

          OmfRc::ResourceFactory.create(:am_controller, {uid: 'am_controller', certificate: @cert}, {manager: @manager})
          puts "AM Resource Controller ready."
        end
      end

    end
  end # AMController
end # module

