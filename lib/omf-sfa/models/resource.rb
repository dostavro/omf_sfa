
module OMF::SFA::Model

  class Resource < Sequel::Model
    plugin :class_table_inheritance
    many_to_one :account

    # add before_save a urn check and set block

    def to_json(options = {})
      values.reject! { |k, v| v.nil? }
      super(options)
    end
  end #Class
end #OMF::SFA
