  
require 'omf_common/lobject'
require 'omf-sfa/am'
require 'nokogiri'
require 'active_support/inflector' # for classify method


module OMF::SFA::AM

  class AMManagerException < Exception; end
  class UnknownResourceException < AMManagerException; end
  class UnavailableResourceException < AMManagerException; end
  class UnknownAccountException < AMManagerException; end
  class FormatException < AMManagerException; end
  class ClosedAccountException < AMManagerException; end
  class InsufficientPrivilegesException < AMManagerException; end
  class UnavailablePropertiesException < AMManagerException; end
  class MissingImplementationException < Exception; end
  class UknownLeaseException < Exception; end

  # Namespace used for reservation information
  OL_NAMESPACE = "http://nitlab.inf.uth.gr/schema/sfa/rspec/1"
  FLEX_NAMESPACE = "http://nitlab.inf.uth.gr/schema/sfa/rspec/lte/1"

  # The manager is where all the AM related policies and
  # resource management is concentrated. Testbeds with their own
  # ways of dealing with resources and components should only
  # need to extend this class.
  #
  class AMManager < OMF::Common::LObject

    attr_accessor :liaison
    # Create an instance of this manager
    #
    # @param [Scheduler] scheduler to use for creating new resource
    #
    def initialize(scheduler)
      @scheduler = scheduler
    end

    def _get_nil_account()
      @scheduler.get_nil_account()
    end

    def get_scheduler()
      @scheduler
    end

    ### MANAGEMENT INTERFACE: adding and removing from the AM's control

    # Register a resource to be managed by this AM.
    #
    # @param [OResource] resource to be managed by this manager
    #
    def manage_resource(resource)
      unless resource.is_a?(OMF::SFA::Model::Resource)
        raise "Resource '#{resource}' needs to be of type 'Resource', but is '#{resource.class}'"
      end

      resource.account_id = _get_nil_account.id
      resource.save
      resource
    end

    # Register an array of resources to be managed by this AM.
    #
    # @param [Array] array of resources
    #
    def manage_resources(resources)
      resources.map {|r| manage_resource(r) }
    end

    ### ACCOUNTS: creating, finding, and releasing accounts

    # Return the account described by +account_descr+. Create if it doesn't exist.
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Account] The requested account
    # @raise [UnknownResourceException] if requested account cannot be created
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_or_create_account(account_descr, authorizer)
      debug "find_or_create_account: '#{account_descr.inspect}'"
      begin
        account = find_account(account_descr, authorizer)
        return account
      rescue UnavailableResourceException
        raise InsufficientPrivilegesException.new unless authorizer.can_create_account?
        account = OMF::SFA::Model::Account.create(account_descr)
        # Ask the corresponding RC to create an account
        @liaison.create_account(account)
      end
      
      raise UnavailableResourceException.new "Cannot create '#{account_descr.inspect}'" unless account
      account
    end

    # Return the account described by +account_descr+.
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Account] The requested account
    # @raise [UnknownResourceException] if requested account cannot be found
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_account(account_descr, authorizer)
      unless account = OMF::SFA::Model::Account.first(account_descr)
        raise UnavailableResourceException.new "Unknown account '#{account_descr.inspect}'"
      end
      raise InsufficientPrivilegesException.new unless authorizer.can_view_account?(account)
      account
    end

    # Return all accounts visible to the requesting user
    #
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<Account>] The visible accounts (maybe empty)
    #
    def find_all_accounts(authorizer)
      accounts = OMF::SFA::Model::Account.exclude(:name => '__default__')
      accounts.map do |a|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_account?(a)
          a
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Renew account described by +account_descr+ hash until +expiration_time+.
    #
    # @param [Hash] properties of account or account object
    # @param [Time] time until account should remain valid
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Account] The requested account
    # @raise [UnknownResourceException] if requested account cannot be found
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def renew_account_until(account_descr, expiration_time, authorizer)
      if account_descr.is_a?(OMF::SFA::Model::Account)
        account = account_descr
      else
        account = find_account(account_descr, authorizer)
      end
      raise InsufficientPrivilegesException unless authorizer.can_renew_account?(account, expiration_time)
      
      account.open if account.closed?  
      account.valid_until = expiration_time
      account.save
      # Ask the corresponding RC to create/re-open an account
      @liaison.create_account(account)

      account
    end

    # Close the account described by +account+ hash.
    #
    # Make sure that all associated components are freed as well
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Account] The closed account
    # @raise [UnknownResourceException] if requested account cannot be found
    # @raise [UnavailableResourceException] if requested account is closed
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def close_account(account_descr, authorizer)
      if account_descr.is_a?(OMF::SFA::Model::Account)
        account = account_descr
      else
        account = find_account(account_descr, authorizer)
      end
      raise InsufficientPrivilegesException unless authorizer.can_close_account?(account)

      #release_all_components_for_account(account, authorizer)
      release_all_leases_for_account(account, authorizer)

      account.close

      @liaison.close_account(account)
      account
    end

    ### USERS

    # Return the user described by +user_descr+. Create if it doesn't exist.
    # Reset its keys if an array of ssh-keys is given
    #
    # Note: This is an unprivileged  operation as creating a user doesn't imply anything
    # else beyond opening a record.
    #
    # @param [Hash] properties of user
    # @return [User] The requested user
    # @raise [UnknownResourceException] if requested user cannot be created
    #
    def find_or_create_user(user_descr, keys = nil)
      debug "find_or_create_user: '#{user_descr.inspect}'"
      begin
        user = find_user(user_descr)
      rescue UnavailableResourceException
        user = OMF::SFA::Model::User.create(user_descr)
      end
      unless keys.nil?
        user.keys.each { |k| k.destroy }
        keys.each do |k|
          key = OMF::SFA::Model::Key.create(ssh_key: k)
          user.add_key(key)
        end
      end
      raise UnavailableResourceException.new "Cannot create '#{user_descr.inspect}'" unless user
      user.save
      user
    end

    # Return the user described by +user_descr+.
    #
    # @param [Hash] properties of user
    # @return [User] The requested user
    # @raise [UnknownResourceException] if requested user cannot be found
    #
    def find_user(user_descr)
      unless user = OMF::SFA::Model::User.first(user_descr)
        raise UnavailableResourceException.new "Unknown user '#{user_descr.inspect}'"
      end
      user
    end

    ### LEASES: creating, finding, and releasing leases

    # Return the lease described by +lease_descr+.
    #
    # @param [Hash] properties of lease
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Lease] The requested lease
    # @raise [UnknownResourceException] if requested lease cannot be found
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_lease(lease_descr, authorizer)
      unless lease = OMF::SFA::Model::Lease.first(lease_descr)
        raise UnavailableResourceException.new "Unknown lease '#{lease_descr.inspect}'"
      end
      raise InsufficientPrivilegesException unless authorizer.can_view_lease?(lease)
      lease
    end

    # Return the lease described by +lease_descr+. Create if it doesn't exist.
    #
    # @param [Hash] lease_descr properties of lease
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Lease] The requested lease
    # @raise [UnknownResourceException] if requested lease cannot be created
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_or_create_lease(lease_descr, authorizer)
      debug "find_or_create_lease: '#{lease_descr.inspect}'"
      begin
        return find_lease(lease_descr, authorizer)
      rescue UnavailableResourceException
      end
      raise InsufficientPrivilegesException unless authorizer.can_create_resource?(lease_descr, 'lease')
      lease = OMF::SFA::Model::Lease.create(lease_descr)

      raise UnavailableResourceException.new "Cannot create '#{lease_descr.inspect}'" unless lease
      @scheduler.add_lease_events_on_event_scheduler(lease) 
      @scheduler.list_all_event_scheduler_jobs #debug messages only
      lease
      # lease = create_resource(lease_descr, 'Lease', lease_properties, authorizer)
    end

    # Find al leases if no +account+ and +status+ is given
    #
    # @param [Account] filter the leases by account
    # @param [Status] filter the leases by their status ['pending', 'accepted', 'active', 'past', 'cancelled']
    # @param [Authorizer] Authorization context
    # @return [Lease] The requested leases
    #
    def find_all_leases(account = nil, status = ['pending', 'accepted', 'active', 'past', 'cancelled'], authorizer)
      debug "find_all_leases: account: #{account.inspect} status: #{status}"
      if account.nil?
        leases = OMF::SFA::Model::Lease.where(status: status)
      else
        leases = OMF::SFA::Model::Lease.where(account_id: account.id, status: status)
      end
      leases.map do |l|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_lease?(l)
          l
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Modify lease described by +lease_descr+ hash
    #
    # @param [Hash] lease properties like ":valid_from" and ":valid_until"
    # @param [Lease] lease to modify
    # @param [Authorizer] Authorization context
    # @return [Lease] The requested lease
    #
    def modify_lease(lease_properties, lease, authorizer)
      raise InsufficientPrivilegesException unless authorizer.can_modify_lease?(lease)
      # lease.update(lease_properties)
      @scheduler.update_lease(lease, lease_properties)
      @scheduler.update_lease_events_on_event_scheduler(lease)
      lease
    end

    # cancel +lease+
    #
    # This implementation simply frees the lease record
    # and destroys any child components if attached to the lease
    #
    # @param [Lease] lease to release
    # @param [Authorizer] Authorization context
    #
    def release_lease(lease, authorizer)
      debug "release_lease: lease:'#{lease.inspect}' authorizer:'#{authorizer.inspect}'"
      raise InsufficientPrivilegesException unless authorizer.can_release_lease?(lease)
      @scheduler.release_lease(lease)
    end

    # Release an array of leases.
    #
    # @param [Array<Lease>] Leases to release
    # @param [Authorizer] Authorization context
    def release_leases(leases, authorizer)
      leases.each do |l|
        release_lease(l, authorizer)
      end
    end

    # This method finds all the leases of the specific account and
    # releases them.
    #
    # @param [Account] Account who owns the leases
    # @param [Authorizer] Authorization context
    #
    def release_all_leases_for_account(account, authorizer)
      leases = find_all_leases(account, ['accepted', 'active'], authorizer)
      release_leases(leases, authorizer)
    end


    ### RESOURCES creating, finding, and releasing resources


    # Find a resource. If it doesn't exist throws +UnknownResourceException+
    # If it's not visible to requester throws +InsufficientPrivilegesException+
    #
    # @param [Hash, Resource] describing properties of the requested resource
    # @param [String] The type of resource we are trying to find
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    # @raise [FormatException] if the resource description is not Hash
    # @raise [InsufficientPrivilegesException] if the resource is not visible to the requester
    #
    #
    def find_resource(resource_descr, resource_type, authorizer)
      debug "find_resource: descr: '#{resource_descr.inspect}'"
      if resource_descr.kind_of? OMF::SFA::Model::Resource
        resource = resource_descr
      elsif resource_descr.kind_of? Hash
        resource = eval("OMF::SFA::Model::#{resource_type.camelize}").first(resource_descr)
      else
        raise FormatException.new "Unknown resource description type '#{resource_descr.class}' (#{resource_descr})"
      end
      unless resource
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist"
      end
      raise InsufficientPrivilegesException unless authorizer.can_view_resource?(resource)
      resource
    end

    # Find all the resources that fit the description. If it doesn't exist throws +UnknownResourceException+
    # If it's not visible to requester throws +InsufficientPrivilegesException+
    #
    # @param [Hash] describing properties of the requested resource
    # @param [String] The type of resource we are trying to find
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    # @raise [FormatException] if the resource description is not Hash
    # @raise [InsufficientPrivilegesException] if the resource is not visible to the requester
    #
    #
    def find_all_resources(resource_descr, resource_type, authorizer)
      debug "find_resources: descr: '#{resource_descr.inspect}'"
      if resource_descr.kind_of? Hash
        resources = eval("OMF::SFA::Model::#{resource_type.classify}").where(resource_descr)
      else
        raise FormatException.new "Unknown resource description type '#{resource_descr.class}' (#{resource_descr})"
      end
      raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist" if resources.nil? || resources.empty?


      resources.map do |r|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find all components matching the resource description that are not leased for the given timeslot.
    # If it doesn't exist, or is not visible to requester
    # throws +UnknownResourceException+.
    #
    # @param [Hash] description of components
    # @param [String] The type of components we are trying to find
    # @param [String, Time] beggining of the timeslot 
    # @param [String, Time] ending of the timeslot
    # @return [Array] All availlable components
    # @raise [UnknownResourceException] if no matching resource can be found
    #
    def find_all_available_components(component_descr = {}, component_type, valid_from, valid_until, authorizer)
      debug "find_all_available_components: descr: '#{component_descr.inspect}', from: '#{valid_from}', until: '#{valid_until}'"
      component_descr[:account_id] = _get_nil_account.id
      components = find_all_resources(component_descr, component_type, authorizer)
      
      components = components.select do |res|
        @scheduler.component_available?(res, valid_from, valid_until)
      end

      raise UnavailableResourceException if components.empty?
      components
    end

    # Find a number of components matching the resource description that are not leased for the given timeslot.
    # If it doesn't exist, or is not visible to requester
    # throws +UnknownResourceException+.
    #
    # @param [Hash] description of components
    # @param [String] The type of components we are trying to find
    # @param [String, Time] beggining of the timeslot 
    # @param [String, Time] ending of the timeslot
    # @param [Array] array of component uuids that are not eligible to be returned by this function 
    # @param [Integer] number of available components to be returned by this function
    # @return [Array] All availlable components
    # @raise [UnknownResourceException] if no matching resource can be found
    #
    def find_available_components(component_descr, component_type, valid_from, valid_until, non_valid_component_uuids = [], nof_requested_components = 1, authorizer)
      debug "find_all_available_components: descr: '#{component_descr.inspect}', from: '#{valid_from}', until: '#{valid_until}'"
      component_descr[:account_id] = _get_nil_account.id
      components = find_all_resources(component_descr, component_type, authorizer)
      components.shuffle! # this randomizes the result
      
      output = []
      components.each do |comp|
        next if non_valid_component_uuids.include?(comp.uuid)
        output << comp if @scheduler.component_available?(comp, valid_from, valid_until) 
        break if output.size >= nof_requested_components
      end

      raise UnavailableResourceException if output.size < nof_requested_components
      output
    end

    # Find all resources for a specific account. Return the managed resources
    # if no account is given
    #
    # @param [Account] Account for which to find all associated resources
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<Resource>] The resource requested
    #
    def find_all_resources_for_account(account = nil, authorizer)
      debug "find_all_resources_for_account: #{account.inspect}"
      account = _get_nil_account if account.nil?
      res = OMF::SFA::Model::Resource.where(account_id: account.id)
      res.map do |r|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find all components for a specific account. Return the managed components
    # if no account is given
    #
    # @param [Account] Account for which to find all associated component
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<Component>] The component requested
    #
    def find_all_components_for_account(account = _get_nil_account, authorizer)
      debug "find_all_components_for_account: #{account.inspect}"
      res = OMF::SFA::Model::Component.where(:account_id => account.id)
      res.map do |r|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find all components
    #
    # @param [Hash] Properties used for filtering the components
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<Component>] The components requested
    #
    def find_all_components(comp_descr, authorizer)
      res = OMF::SFA::Model::Component.where(comp_descr)
      res.map do |r|
        begin
          raise InsufficientPrivilegesException unless authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find or Create a resource. If an account is given in the resource description
    # a child resource is created. Otherwise a managed resource is created. 
    #
    # @param [Hash] Describing properties of the resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] The resource requested
    # @raise [UnknownResourceException] if no resource can be created
    #
    def find_or_create_resource(resource_descr, resource_type, authorizer)
      debug "find_or_create_resource: resource '#{resource_descr.inspect}' type: '#{resource_type}'"
      unless resource_descr.is_a? Hash
        raise FormatException.new "Unknown resource description '#{resource_descr.inspect}'"
      end
      begin
        return find_resource(resource_descr, resource_type, authorizer)
      rescue UnknownResourceException
      end
      create_resource(resource_descr, resource_type, authorizer)
    end

    # Create a resource. If an account is given in the resource description
    # a child resource is created. The parent resource should be already present and managed
    # This will provide a copy of the actual physical resource.
    # Otherwise a managed resource is created which belongs to the 'nil_account'
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] The resource requested
    # @raise [UnknownResourceException] if no resource can be created
    #
    def create_resource(resource_descr, type_to_create, authorizer)
      raise InsufficientPrivilegesException unless authorizer.can_create_resource?(resource_descr, type_to_create)

      if resource_descr[:account_id].nil?
        resource = eval("OMF::SFA::Model::#{type_to_create.classify}").create(resource_descr)
        resource = manage_resource(resource)
      else
        resource = @scheduler.create_child_resource(resource_descr, type_to_create)
      end

      raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' cannot be created" unless resource
      resource
    end

    # Find or create a resource for an account. If it doesn't exist,
    # is already assigned to someone else, or cannot be created, throws +UnknownResourceException+.
    #
    # @param [Hash] describing properties of the requested resource
    # @param [String] Type to create if not already exist
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    #
    def find_or_create_resource_for_account(resource_descr, type_to_create, authorizer)
      debug "find_or_create_resource_for_account: r_descr:'#{resource_descr}' type:'#{type_to_create}' authorizer:'#{authorizer.inspect}'"
      resource_descr[:account_id] = authorizer.account.id
      find_or_create_resource(resource_descr, type_to_create, authorizer)
    end


    def create_resources_from_rspec(descr_el, clean_state, authorizer)
      debug "create_resources_from_rspec: descr_el: '#{descr_el}' clean_state: '#{clean_state}' authorizer: '#{authorizer}'"

      resources = descr_el.children.map do |child|
        n = OMF::SFA::Model::Component.create_from_rspec(child, resources, self)
        child.create_from_rspec(authorizer)
      end
    end

    # Release 'resource'.
    #
    # This implementation simply frees the resource record.
    #
    # @param [Resource] Resource to release
    # @param [Authorizer] Authorization context
    # @raise [InsufficientPrivilegesException] if the resource is not allowed to be released
    #
    def release_resource(resource, authorizer)
      debug "release_resource: '#{resource.inspect}'"
      raise InsufficientPrivilegesException unless authorizer.can_release_resource?(resource)
      @scheduler.release_resource(resource)
    end

    # Release an array of resources.
    #
    # @param [Array<Resource>] Resources to release
    # @param [Authorizer] Authorization context
    def release_resources(resources, authorizer)
      resources.each do |r|
        release_resource(r, authorizer)
      end
    end

    # This method finds all the components of the specific account and
    # detaches them.
    #
    # @param [Account] Account who owns the components
    # @param [Authorizer] Authorization context
    #
    def release_all_components_for_account(account, authorizer)
      components = find_all_components_for_account(account, authorizer)
      release_resources(components, authorizer)
    end


    # Update the resources described in +resource_el+. Any resource not already assigned to the
    # requesting account will be added. If +clean_state+ is true, the state of all described resources
    # is set to the state described with all other properties set to their default values. Any resources
    # not mentioned are released. Returns the list
    # of resources requested or throw an error if ANY of the requested resources isn't available.
    #
    # Find or create a resource. If it doesn't exist, is already assigned to
    # someone else, or cannot be created, throws +UnknownResourceException+.
    #
    # @param [Element] RSpec fragment describing resource and their properties
    # @param [Boolean] Set all properties not mentioned to their defaults
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    # @raise [FormatException] if RSpec elements are not known
    #
    # @note Throws exception if a contained resource doesn't exist, but will not roll back any
    # already performed modifications performed on other resources.
    #
    def update_resources_from_rspec(descr_el, clean_state, authorizer)
      debug "update_resources_from_rspec: descr_el:'#{descr_el}' clean_state:'#{clean_state}' authorizer:'#{authorizer}'"
      if !descr_el.nil? && descr_el.name.downcase == 'rspec'
        xsd_path = File.join(File.dirname(__FILE__), '../../../schema/rspec-v3', 'request.xsd')
        schema = Nokogiri::XML::Schema(File.open(xsd_path))

        #TODO: make sure we pass the schema validation
        #res = schema.validate(descr_el.document)
        #raise FormatException.new("RSpec format is not valid: '#{res}'") unless res.empty?

        unless descr_el.xpath('//ol:*', 'ol' => OL_NAMESPACE).empty?
          #TODO: make proper schemas and validate them
          #lease_xsd_path = File.join(File.dirname(__FILE__), '../../../schema/rspec-v3', 'request-reservation.xsd')
          #lease_rng_path = File.join(File.dirname(__FILE__), '../../../schema/rspec-v3', 'request-reservation.rng')
          #lease_schema = Nokogiri::XML::Schema(File.open(lease_xsd_path))
          #lease_schema = Nokogiri::XML::RelaxNG(File.open(lease_rng_path))

          #TODO: make sure we pass the schema validation
          #res = schema.validate(descr_el.document)
          #raise FormatException.new("RSpec format is not valid: '#{res}'") unless res.empty?
        end


        if descr_el.namespaces.values.include?(OL_NAMESPACE)
          leases = descr_el.xpath('//ol:lease', 'ol' => OL_NAMESPACE)
          # leases = descr_el.xpath('/xmlns:rspec/ol:lease', 'ol' => OL_NAMESPACE, 'xmlns' => "http://www.geni.net/resources/rspec/3")
          leases = update_leases_from_rspec(leases, authorizer)
        else
          leases = {}
        end

        resources = leases.values

        nodes = descr_el.xpath('//xmlns:node').collect do |el|
          #debug "create_resources_from_xml::EL: #{el.inspect}"
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            #if el[:lease_name].nil?
            #  update_resource_from_rspec(el, nil, clean_state, authorizer)
            #else # This node has a lease
            #  lease = leases.find { |l| l[:name].eql?(el[:lease_name]) }
            #leases = el.xpath('child::ol:lease', 'ol' => OL_NAMESPACE)
            #leases = update_leases_from_rspec(leases, authorizer)
            update_resource_from_rspec(el, leases, clean_state, authorizer)
            #end
          end
        end.compact

        resources = resources.concat(nodes)

        # channel reservation
        channels = descr_el.xpath('/xmlns:rspec/ol:channel', 'ol' => OL_NAMESPACE, 'xmlns' => "http://www.geni.net/resources/rspec/3").collect do |el|
          update_resource_from_rspec(el, leases, clean_state, authorizer)
        end.compact

        resources = resources.concat(channels)

        # e_node_b reservation
        e_node_bs = descr_el.xpath('/xmlns:rspec/flex:e_node_b', 'flex' => FLEX_NAMESPACE, 'xmlns' => "http://www.geni.net/resources/rspec/3").collect do |el|
          update_resource_from_rspec(el, leases, clean_state, authorizer)
        end.compact

        resources = resources.concat(e_node_bs)

        # if resources.include?(false) # a component failed to be leased because of scheduler lease_component returned false
        #   resources.delete(false)
        #   release_resources(resources, authorizer)
        #   raise UnavailableResourceException.new "One or more resources failed to be allocated"
        # end

        failed_resources = []
        resources.each do |res|
          failed_resources << res if res.kind_of? Hash
        end

        unless failed_resources.empty?
          resources.delete_if {|item| failed_resources.include?(item)}
          urns = []
          failed_resources.each do |fres|
            release_resource(fres[:failed], authorizer)
            urns << fres[:failed].urn
          end
          release_resources(resources, authorizer)
          raise UnavailableResourceException.new "The resources with the following URNs: '#{urns.inspect}' failed to be allocated"
        end

        # TODO: release the unused leases. The leases we have created but we never managed
        # to attach them to a resource because the scheduler denied it.
        if clean_state
          # Now free any leases owned by this account but not contained in +leases+
          # all_leases = Set.new(leases.values)
          #leases = descr_el.xpath('//ol:lease', 'ol' => OL_NAMESPACE).collect do |l|
          #  update_leases_from_rspec(leases, authorizer)
          #end.compact

          # leases.each_value {|l| l.all_resources(all_leases)}
          all_leases = find_all_leases(authorizer.account, authorizer)
          leases_values = leases.values
          unused = all_leases.delete_if do |l|
            out = leases_values.select {|res| res.id == l.id}
            !out.empty?
          end
          # unused = find_all_leases(authorizer.account, authorizer).to_set - all_leases
          unused.each do |u|
            release_lease(u, authorizer)
          end
          # Now free any resources owned by this account but not contained in +resources+
          # rspec_resources = Set.new(resources)
          # resources.each {|r| r.all_resources(rspec_resources)}
          all_components = find_all_components_for_account(authorizer.account, authorizer)
          unused = all_components.delete_if do |comp|
            out = resources.select {|res| res.id == comp.id}
            !out.empty?
          end

          release_resources(unused, authorizer)
        end
        return resources
      else
        raise FormatException.new "Unknown resources description root '#{descr_el}'"
      end
    end

    # Update a single resource described in +resource_el+. The respective account is
    # extracted from +opts+. Any mentioned resources not already available to the requesting account
    # will be created. If +clean_state+ is set to true, all state of a resource not specifically described
    # will be reset to it's default value. Returns the resource updated.
    #
    def update_resource_from_rspec(resource_el, leases, clean_state, authorizer)
      if uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['id'])
        uuid = UUIDTools::UUID.parse(uuid_attr.value)
        resource = find_resource({:uuid => uuid}, authorizer) # wouldn't know what to create
      elsif comp_id_attr = resource_el.attributes['component_id']
        comp_id = comp_id_attr.value
        comp_gurn = OMF::SFA::Model::GURN.parse(comp_id)
        #if uuid = comp_gurn.uuid
        #  resource_descr = {:uuid => uuid}
        #else
        #  resource_descr = {:name => comp_gurn.short_name}
        #end
        resource_descr = {:urn => comp_gurn.to_s}
        resource = find_or_create_resource_for_account(resource_descr, comp_gurn.type, authorizer)
        unless resource
          raise UnknownResourceException.new "Resource '#{resource_el.to_s}' is not available or doesn't exist"
        end
      elsif name_attr = resource_el.attributes['component_name']
        # the only resource we can find by a name attribute is a group
        # TODO: Not sure about the 'group' assumption
        name = name_attr.value
        resource = find_or_create_resource_for_account({:name => name}, 'unknown', {}, authorizer)
      else
        raise FormatException.new "Unknown resource description '#{resource_el.attributes.inspect}"
      end

      resource.client_id = resource_el['client_id']
      resource.save

      leases_el = resource_el.xpath('child::ol:lease_ref|child::ol:lease', 'ol' => OL_NAMESPACE)
      leases_el.each do |lease_el|
        #TODO: provide the scheduler with the resource and the lease to attach them according to its policy.
        # if the scheduler refuses to attach the lease to the resource, we should release both of them.
        # start by catching the exceptions of @scheduler
        lease_id = lease_el['id_ref'] || lease_el['client_id']
        lease = leases[lease_id]

        unless lease.nil? || lease.components.include?(resource)#lease.components.first(:uuid => resource.uuid)
          return {failed: resource} unless @scheduler.lease_component(lease, resource) 

          monitoring_el = resource_el.xpath('//xmlns:monitoring')
          unless monitoring_el.empty?
            oml_url = monitoring_el.first.xpath('//xmlns:oml_server').first['url']
            @liaison.start_resource_monitoring(resource, lease, oml_url)
          end
        end
      end

      # if resource.group?
      #   members = resource_el.children.collect do |el|
      #     if el.kind_of?(Nokogiri::XML::Element)
      #       # ignore any text elements
      #       update_resource_from_rspec(el, clean_state, authorizer)
      #     end
      #   end.compact
      #   debug "update_resource_from_rspec: Creating members '#{members}' for group '#{resource}'"

      #   if clean_state
      #     resource.members = members
      #   else
      #     resource.add_members(members)
      #   end
      # else
      #   if clean_state
      #     # Set state to what's described in +resource_el+ ONLY
      #     resource.create_from_xml(resource_el, authorizer)
      #   else
      #     resource.update_from_xml(resource_el, authorizer)
      #   end
      # end
      sliver_type_el = resource_el.xpath('//xmlns:sliver_type')
      unless sliver_type_el.empty?
        sliver_type = OMF::SFA::Model::SliverType.first({name: sliver_type_el.first['name']})
        resource.sliver_type = sliver_type
      end

      resource.save
      resource

    rescue UnknownResourceException
      error "Ignoring Unknown Resource: #{resource_el}"
      nil
    end

    # Update the leases described in +leases+. Any lease not already assigned to the
    # requesting account will be added. If +clean_state+ is true, the state of all described leases
    # is set to the state described with all other properties set to their default values. Any leases
    # not mentioned are canceled. Returns the list
    # of leases requested or throw an error if ANY of the requested leases isn't available.
    #
    # @param [Element] RSpec fragment describing leases and their properties
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Hash{String => Lease}] The leases requested
    # @raise [UnknownResourceException] if no matching lease can be found
    # @raise [FormatException] if RSpec elements are not known
    #
    def update_leases_from_rspec(leases, authorizer)
      debug "update_leases_from_rspec: leases:'#{leases.inspect}' authorizer:'#{authorizer.inspect}'"
      leases_hash = {}
      unless leases.empty?
        leases.each do |lease|
          l = update_lease_from_rspec(lease, authorizer)
          leases_hash.merge!(l)
        end
      end
      leases_hash
    end

    # Create or Modify leases through RSpecs
    #
    # When a UUID is provided, then the corresponding lease is modified. Otherwise a new
    # lease is created with the properties described in the RSpecs.
    #
    # @param [Nokogiri::XML::Node] RSpec fragment describing lease and its properties
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Lease] The requested lease
    # @raise [UnavailableResourceException] if no matching resource can be found or created
    # @raise [FormatException] if RSpec elements are not known
    #
    def update_lease_from_rspec(lease_el, authorizer)

      if (lease_el[:valid_from].nil? || lease_el[:valid_until].nil?)
        raise UnavailablePropertiesException.new "Cannot create lease without ':valid_from' and 'valid_until' properties"
      end

      lease_properties = {:valid_from => Time.parse(lease_el[:valid_from]).utc, :valid_until => Time.parse(lease_el[:valid_until]).utc}

      begin
        raise UnavailableResourceException unless UUID.validate(lease_el[:id])
        lease = find_lease({:uuid => lease_el[:id]}, authorizer)
        # if lease.valid_from != lease_properties[:valid_from] || lease.valid_until != lease_properties[:valid_until]
        #   lease = modify_lease(lease_properties, lease, authorizer)
        #   return { lease_el[:id] => lease }
        # else
        #   return { lease_el[:id] => lease }
        # end
        return { lease_el[:id] => lease }
      rescue UnavailableResourceException
        lease_descr = {account_id: authorizer.account.id, valid_from: lease_el[:valid_from], valid_until: lease_el[:valid_until]}
        lease = find_or_create_lease(lease_descr, authorizer)
        lease.client_id = lease_el[:client_id]
        lease.save
        return { (lease_el[:client_id] || lease_el[:id]) => lease }
      end
    end

    def sfa_response_xml(resources, opts)
      OMF::SFA::Model::Component.sfa_response_xml(resources, opts).to_xml
    end

    def configure_user_keys(users, authorizer)
      all_keys = []
      users.each do |user|
        gurn = OMF::SFA::Model::GURN.parse(user["urn"])
        u = self.find_or_create_user({urn: gurn.urn}, user["keys"])
        u.keys.each do |k|
          all_keys << k unless all_keys.include? k
        end
        unless authorizer.account.users.include?(u) 
          authorizer.account.add_user(u) 
          authorizer.account.save
        end
      end
      @liaison.configure_keys(all_keys, authorizer.account)
    end
  end # class
end # OMF::SFA::AM
