require 'omf-sfa/models/resource'
require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Lease < Resource
    many_to_many :components, :left_key=>:lease_id, :right_key=>:component_id,
    :join_table=>:components_leases


    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa_class 'lease', :namespace => :ol, :can_be_referred => true
    sfa :valid_from, :attribute => true
    sfa :valid_until, :attribute => true
    sfa :client_id, :attribute => true

    def self.include_nested_attributes_to_json
      sup = super
      [:components].concat(sup)
    end

    def before_save
      self.status = 'pending' if self.status.nil?
      self.valid_until = Time.parse(self.valid_until) if self.valid_until.kind_of? String
      self.valid_from = Time.parse(self.valid_from) if self.valid_from.kind_of? String
      # Get rid of the milliseconds
      self.valid_from = Time.at(self.valid_from.to_i) unless valid_from.nil?
      self.valid_until = Time.at(self.valid_until.to_i) unless valid_until.nil?
      super
    end
  end
end
