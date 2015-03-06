require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Cpu < Component

    many_to_one :node

    plugin :nested_attributes
    nested_attributes :node

    def exclude_from_json
      [:node_id]
    end
  end
end
