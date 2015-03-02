require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/am/am_manager'

module OMF::SFA::AM::Rest

  # Handles an resource membderships
  #
  class MappingHandler < ResourceHandler

    # List a resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the requested resource.
    def on_get(resource_uri, opts)
      debug "on_get: #{resource_uri}"
      body, format = parse_body(opts)
      authenticator = opts[:req].session[:authorizer]
      response = resolve_unbound_request(body, format, authenticator)
      response
    end

    # Create a new resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri}"
      body, format = parse_body(opts)
      authenticator = opts[:req].session[:authorizer]
      response = resolve_unbound_request(body, format, authenticator)
      response
    end

    # Update an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the updated resource.
    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    # Deletes an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_delete(resource_uri, opts)
      debug "on_delete: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    protected
    # This method uses the am_scheduler's resolve_query method to resolve an unbound request.
    #
    # @param [Hash] Body of the request (should be in json format)
    # @param [Symbol] The format of the body (only :json is valid)
    # @param [Authorizer] Defines context for authorization decisions
    # @return [String] The output, a json as a string
    # @raise [UnknownResourceException] No available resources
    # @raise [BadRequestException] No type given in the json input
    # @raise [UnsupportedBodyFormatException] The given format is no supported
    #
    def resolve_unbound_request(body, format, authenticator)
      if format == :json
        begin
          resource = @am_manager.get_scheduler.resolve_query(body, @am_manager, authenticator)
          debug "response: #{resource}, #{resource.class}"
          return ['application/json', JSON.pretty_generate({:resource_response => resource}, :for_rest => true)]
        rescue OMF::SFA::AM::UnavailableResourceException
          raise UnknownResourceException, "There are no available resources matching the request."
        rescue MappingSubmodule::UnknownTypeException
          raise BadRequestException, "Missing the mandatory parameter 'type' from one of the requested resources."
        end
      else
        raise UnsupportedBodyFormatException, "Format '#{format}' is not supported, please try json."
      end
    end
  end # ResourceHandler
end # module
