require 'omf-sfa/models/component'
require 'omf-sfa/models/node'
require 'omf-sfa/models/ip'

module OMF::SFA::Model
  class Cmc < Component

    one_to_one :node
    many_to_one :ip

    plugin :nested_attributes
    nested_attributes :node, :ip
  end
end
