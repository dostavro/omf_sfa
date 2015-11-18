require 'omf-sfa/models/component'
require 'omf-sfa/models/interface'

module OMF::SFA::Model
  class UsrpEthernetDevice < Component
    one_to_many :interfaces

    plugin :nested_attributes
    nested_attributes :interfaces

    # sfa_class 'usrp_ethernet_device', :can_be_referred => true, :expose_id => false

    # def self.exclude_from_json
    #   sup = super
    #   [].concat(sup)
    # end

    def self.include_nested_attributes_to_json
      sup = super
      [:interfaces].concat(sup)
    end
  end
end
