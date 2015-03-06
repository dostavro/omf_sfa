module OMF::SFA::Model

  class GURN

    # Create a GURN
    #
    # @param [String] name Name of GURN
    # @param [Hash] opts options to further describe GURN components
    # @option opts [String] :type GURN's type
    # @option opts [Class] :model Class responding to either :sfa_class or :resource_type
    # @option opts [String] :domain GURN's domain
    #
    def self.create(name, opts = {})
      return name if name.kind_of? self

      if name.start_with?('urn')
        return parse(name)
      end

      unless type = opts[:type]
        model = opts[:model]
        if model && model.respond_to?(:sfa_class)
          type =  model.sfa_class
          type = type.split(":").last if type.include?(':')
        elsif model && model.respond_to?(:resource_type)
          type =  model.resource_type
        end
      end
      domain = opts[:domain] || Constants.default_domain
      self.new(name, type, domain)
    end

    # Create a GURN object from +urn_str+.
    #
    def self.parse(urn_str)
      if urn_str.start_with? 'urn:publicid:IDN'
        a = urn_str.split('+')
        a.delete_at(0) # get rid of "urn:publicid:IDN"
        if a.length == 3
          prefix, type, name = a
        elsif a.length == 2
          prefix, name = a
          type = nil
        else
          raise "unknown format '#{urn_str}' for GURN (#{a.inspect})."
        end
        self.new(name, type, prefix)
      else
        raise "unknown format '#{urn_str}' for GURN - expected it to start with 'urn:publicid:IDN'."
      end
    end

    attr_reader :name, :short_name, :type, :domain, :urn

    def initialize(short_name, type = nil, domain = nil)
      @short_name = short_name
      @domain = domain || Constants.default_domain
      if type
        @type = type
        @name = "#{@domain}+#{type}+#{short_name}"
      else
        @name = "#{@domain}+#{short_name}"
      end
      @urn = 'urn:publicid:IDN+' + name
    end

    def to_s
      @urn
    end

  end # GURN
end # OMF::SFA::Model
