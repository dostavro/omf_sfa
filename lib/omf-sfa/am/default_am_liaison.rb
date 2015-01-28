require 'omf_common'
require 'omf-sfa/am/am_manager'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class DefaultAMLiaison < OMF::Common::LObject

    include OmfCommon
    include OmfCommon::Auth

    attr_accessor :comm
    @leases = {}

    def initialize
      EM.next_tick do
        OmfCommon.comm.on_connected do |comm|
          puts "#{self.class}: AMLiaison ready."
        end
      end
    end

    def create_account(account)
      warn "Am liason: create_account: Not implemented."
    end

    def close_account(account)
      warn "Am liason: close_account: Not implemented."
    end

    def configure_keys(keys, account)
      warn "Am liason: configure_keys: Not implemented."
    end


    # It will send the corresponding create messages to the components contained
    # in the lease when the lease is about to start. At the end of the
    # lease the corresponding release messages will be sent to the components.
    #
    # @param [Lease] lease Contains the lease information "valid_from" and
    #                 "valid_until" along with the reserved components
    #
    def enable_lease(lease, component)
      warn "Am liason: enable_lease: Not implemented."
    end

    def create_resource(resource, lease, component)
      warn "Am liason: create_resource: Not implemented."
    end

    def release_resource(resource, new_res, lease, component)
      warn "Am liason: release_resource: Not implemented."
    end
  end # DefaultAMLiaison
end # OMF::SFA::AM

