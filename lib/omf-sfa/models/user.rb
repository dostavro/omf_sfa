require 'models/resource'

module OMF::SFA::Model
  class User < Resource
    one_to_many :resources
    many_to_many :accounts
  end
end
