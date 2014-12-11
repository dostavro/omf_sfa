require 'models/resource'

module OMF::SFA::Model
  class Account < Resource
    one_to_many :resources
    many_to_many :users
  end
end
