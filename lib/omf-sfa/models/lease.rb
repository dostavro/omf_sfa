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
    sfa :sliver_id, :attribute => true

    def self.include_nested_attributes_to_json
      sup = super
      [:components].concat(sup)
    end

    def before_save
      self.status = 'pending' if self.status.nil?
      self.name = self.uuid if self.name.nil?
      self.valid_until = Time.parse(self.valid_until) if self.valid_until.kind_of? String
      self.valid_from = Time.parse(self.valid_from) if self.valid_from.kind_of? String
      # Get rid of the milliseconds
      self.valid_from = Time.at(self.valid_from.to_i) unless valid_from.nil?
      self.valid_until = Time.at(self.valid_until.to_i) unless valid_until.nil?
      super
      self.urn = GURN.create(self.name, :type => 'sliver').to_s if GURN.parse(self.urn).type == 'lease'
    end

    def sliver_id
      self.urn
    end

    def active?
      return false if self.status == 'cancelled' || self.status == 'past'
      t_now = Time.now
      t_now >= self.valid_from && t_now < self.valid_until
    end

    def to_hash
      values.reject! { |k, v| v.nil?}
      values[:components] = []
      self.components.each do |component|
        next if ((self.status == 'active' || self.status == 'accepted') && component.account.id == 2)
        values[:components] << component.to_hash_brief
      end
      values[:account] = self.account ? self.account.to_hash_brief : nil
      excluded = self.class.exclude_from_json
      values.reject! { |k, v| excluded.include?(k)}
      values
    end

    def to_hash_brief
      values[:account] = self.account.to_hash_brief unless self.account.nil?
      super
    end

    def allocation_status
      return "geni_unallocated" if self.status == 'pending' || self.status == 'cancelled'
      return "geni_allocated" unless self.status == 'active'
      ret = 'geni_provisioned'
      self.components.each do |comp|
        if comp.resource_type == 'node' && comp.status != 'geni_provisioned'
          ret = 'geni_allocated'
          break
        end
      end
      ret
    end

    def operational_status
      case self.status
      when 'pending'
        "geni_failed"
      when 'accepted'
        "geni_pending_allocation"
      when "active"
        "geni_ready"
      when 'cancelled'
        "geni_unallocated"
      else
        self.status
      end
    end
  end
end
