require 'omf_common/lobject'
require 'active_support/inflector'
require 'uuid'
require "uuidtools"

module OMF::SFA::Model

  class Resource < Sequel::Model
    plugin :class_table_inheritance
    many_to_one :account

    plugin :nested_attributes
    nested_attributes :account

    # add before_save a urn check and set block
    # save also the resource_type 'node, channel etc.'

    def before_save
      self.resource_type ||= self.class.to_s.split('::')[-1].downcase
      self.uuid ||= UUIDTools::UUID.random_create
      name = self.name ? self.name : self.uuid
      self.urn ||= GURN.create(name, :type => self.class.to_s.split('::')[-1].downcase).to_s
      super
    end

    def to_json(options = {})
      values.reject! { |k, v| v.nil? }
      super(options)
    end

    def to_hash
      values.reject! { |k, v| v.nil? || (k == :account_id && v == 2)}
      included = self.class.include_nested_attributes_to_json
      included.each do |assoc|
        res = self.send(assoc)
        next if res.nil? 
        if res.kind_of? Array
          next if res.empty?
          values[assoc] = []
          res.each do |val|
            values[assoc] << val.to_hash_brief
          end
        elsif res.kind_of? OMF::SFA::Model::Resource
          # next if assoc == :account && !res.account.nil? && res.account.id == 2 # nil account
          values[assoc] = res.to_hash_brief
        end
        
      end
      excluded = self.class.exclude_from_json
      values.reject! { |k, v| excluded.include?(k)}
      super
    end

    def to_hash_brief
      values.reject! { |k, v| v.nil? }
      excluded = self.class.exclude_from_json
      values.reject! { |k, v| excluded.include?(k)}
      values
    end

    def clone
      clone = self.class.new
      self.values.each do |key, val|
        next if key == :uuid || key == :id
        next if val == nil
        desc = {}
        desc[key] = val
        clone.set(desc)
      end

      clone.save
      clone
    end

    def self.exclude_from_json
      [:id, :account_id, :type]
    end

    def self.include_nested_attributes_to_json
      [:account]
    end

    def self.include_to_json(incoming = [])
      return {:account => {:only => [:uuid, :urn, :name]}} if self.instance_of? OMF::SFA::Model::Resource
      out = {}
      self.include_nested_attributes_to_json.each do |key|
        next if incoming.include?(key)
        next if key == :account && self.name != 'OMF::SFA::Model::Lease'
        next if self.name == "OMF::SFA::Model::#{key.to_s.classify}"
        out[key] = {}
        begin
          out[key][:except] = eval("OMF::SFA::Model::#{key.to_s.classify}").exclude_from_json
          out[key][:include] = eval("OMF::SFA::Model::#{key.to_s.classify}").include_to_json(incoming << key)
        rescue NameError => ex
          # out.delete(key)
          key_class = key.to_s.split('_').last
          out[key] = {}
          out[key][:except] = eval("OMF::SFA::Model::#{key_class.to_s.classify}").exclude_from_json
          out[key][:include] = eval("OMF::SFA::Model::#{key_class.to_s.classify}").include_to_json(incoming << key)
        end
      end
      out
    end
  end #Class
end #OMF::SFA

OMF::SFA::Model::Resource.plugin :class_table_inheritance, :key=>:type

class Array
  def to_json(options = {})
    JSON.generate(self)
  end
end

class Hash
  def to_json(options = {})
    JSON.generate(self)
  end
end

class Time
  def to_json(options = {})
    super
  end
end
