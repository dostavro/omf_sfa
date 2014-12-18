require 'active_support/inflector'

module OMF::SFA::Model

  class Resource < Sequel::Model
    plugin :class_table_inheritance
    many_to_one :account

    plugin :nested_attributes
    nested_attributes :account

    # add before_save a urn check and set block

    def to_json(options = {})
      values.reject! { |k, v| v.nil? }
      super(options)
    end

    def to_hash
      values.reject! { |k, v| v.nil? }
      super
    end

    def self.exclude_from_json
      [:id, :account_id]
    end

    def self.include_nested_attributes_to_json
      [:account]
    end

    def self.include_to_json(incoming = [])
      return {:account => {:only => [:uuid, :urn, :name]}} if self.instance_of? OMF::SFA::Model::Resource
      out = {}
      self.include_nested_attributes_to_json.each do |key|
        next if incoming.include?(key)
        next if key == :account && !self.instance_of?(OMF::SFA::Model::Lease)
        next if self.instance_of? eval("OMF::SFA::Model::#{key.to_s.classify}")
        out[key] = {}
        out[key][:except] = eval("OMF::SFA::Model::#{key.to_s.classify}").exclude_from_json
        out[key][:include] = eval("OMF::SFA::Model::#{key.to_s.classify}").include_to_json(incoming << key)
      end
      out
    end
  end #Class
end #OMF::SFA

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
