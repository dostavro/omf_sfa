require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Key < Resource
    many_to_one :user
  end
end
