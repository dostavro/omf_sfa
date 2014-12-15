
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
