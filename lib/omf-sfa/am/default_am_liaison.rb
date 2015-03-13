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
      @config = OMF::Common::YAML.load('am_liaison_conf', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:am_liaison]
 
      EM.next_tick do
        OmfCommon.comm.on_connected do |comm|
          puts "#{self.class}: AMLiaison ready with opts: #{@config.inspect}."
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

    def create_resource(resource, lease, component)
      warn "Am liason: create_resource: Not implemented."
    end

    def release_resource(resource, new_res, lease, component)
      warn "Am liason: release_resource: Not implemented."
    end

    def start_resource_monitoring(resource, lease, oml_uri=nil)
      warn "Am liason: start_resource_monitoring: Not implemented."
    end

    def on_lease_start(lease)
      warn "Am liason: on_lease_start: Not implemented."
    end

    def on_lease_end(lease)
      warn "Am liason: on_lease_end: Not implemented."
    end
  end # DefaultAMLiaison
end # OMF::SFA::AM

