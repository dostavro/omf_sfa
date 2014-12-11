require 'models/component'
require 'models/node'
require 'models/ip'

module OMF::SFA::Model
  class Cmc < Component

    one_to_one :node
    many_to_one :ip

    plugin :nested_attributes
    nested_attributes :node, :ip
  end
end
