
#require 'omf-sfa/am/privilege_credential'
#require 'omf-sfa/am/user_credential'

require 'omf_rc'
require 'omf_common'

module OmfRc::ResourceProxy::AMController
  include OmfRc::ResourceProxyDSL

  register_proxy :am_controller

  request :resources do |resource|
    debug "manager: #{self.instance_variables}"
    permissions = {:can_view_resource? => true}
    authorizer = OMF::SFA::AM::DefaultAuthorizer.new(permissions)
    resources = @manager.find_all_components_for_account(@manager._get_nil_account, authorizer)
    resources.concat(@manager.find_all_leases(authorizer))
    OMF::SFA::Resource::OResource.resources_to_hash(components)
  end

  hook :before_ready do |resource|
    logger.info "creation opts #{resource.creation_opts}"
    @manager = resource.creation_opts[:manager]
  end
end


module OMF::SFA::AM::XMPP
  #module OmfRc::ResourceProxy::Am_controller

    #class AMController < OmfRc::ResourceProxy::AbstractResource
    class AMController
      #include OmfRc::ResourceProxyDSL
      include OMF::Common::Loggable

      #register_proxy :am_controller

      #request :resources do |resource|
      #  debug "manager: #{self.instance_variables}"
      #  permissions = {:can_view_resource? => true}
      #  authorizer = OMF::SFA::AM::DefaultAuthorizer.new(permissions)
      #  components = @@manager.find_all_components_for_account(@@manager._get_nil_account, authorizer)
      #  OMF::SFA::Resource::OResource.resources_to_hash(components)
      #end

      def initialize(opts)
        @manager = opts[:manager]

        EM.next_tick do
          OmfCommon.comm.on_connected do |comm|
            entity = OmfCommon::Auth::Certificate.create_from_x509(File.read("/home/dostavro/.omf/rc.pem"), File.read("/home/dostavro/.omf/rc_key.pem"))
            OmfCommon::Auth::CertificateStore.instance.register_default_certs("/home/dostavro/.omf/trusted_roots/")
            #OmfCommon::Auth::CertificateStore.instance.register(entity, OmfCommon.comm.local_address)
            #OmfCommon::Auth::CertificateStore.instance.register(entity,'am_controller')
            #super(:am_controller, {uid: 'am_controller', certificate: entity}, {})
            OmfRc::ResourceFactory.create(:am_controller, {uid: 'am_controller', certificate: entity}, {manager: @manager})
            puts "AM Resource Controller ready."
          end
        end

        #@liaison = opts[:liaison]
      end
    end # AMController
  #end
end # module

