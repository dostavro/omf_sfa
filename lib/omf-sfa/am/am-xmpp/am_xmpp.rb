
#require 'omf-sfa/am/privilege_credential'
#require 'omf-sfa/am/user_credential'

require 'omf_rc'
require 'omf_common'

module OMF::SFA::AM::XMPP
  #module OmfRc::ResourceProxy::Am_controller

    class AMController < OmfRc::ResourceProxy::AbstractResource
      include OmfRc::ResourceProxyDSL
      include OMF::Common::Loggable

      #register_proxy :am_controller

      request :resources do |resource|
        debug "manager: #{self.instance_variables}"
        permissions = {:can_view_resource? => true}
        authorizer = OMF::SFA::AM::DefaultAuthorizer.new(permissions)
        components = @@manager.find_all_components_for_account(@@manager._get_nil_account, authorizer)
        OMF::SFA::Resource::OResource.resources_to_hash(components)
      end

      def initialize(opts)
        EM.next_tick do
          OmfCommon.comm.on_connected do |comm|
            super(:am_controller, uid: 'am_controller')
            #OmfRc::ResourceFactory.create(:am_controller, uid: 'am_controller')
            puts "AM Resource Controller ready."
          end
        end

        @@manager = opts[:manager]
        #@liaison = opts[:liaison]
      end
    end # AMController
  #end
end # module

