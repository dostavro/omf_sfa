
require 'omf_common/lobject'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_liaison'
require 'active_support/inflector'



module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Common::LObject

    @@mapping_hook = nil

    # Create a resource of specific type given its description in a hash. We create a clone of itself 
    # and assign it to the user who asked for it (conceptually a physical resource even though it is exclusive,
    # is never given to the user but instead we provide him a clone of the resource).
    #
    # @param [Hash] resource_descr contains the properties of the new resource
    # @param [String] The type of the resource we want to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Resource] Returns the created resource
    #
    def create_child_resource(resource_descr, type_to_create)
      debug "create_child_resource: resource_descr:'#{resource_descr}' type_to_create:'#{type_to_create}'"

      desc = resource_descr.dup
      desc[:account_id] = get_nil_account.id

      type = type_to_create.classify

      parent = eval("OMF::SFA::Model::#{type}").first(desc)

      if parent.nil? || !parent.available
        raise UnknownResourceException.new "Resource '#{desc.inspect}' is not available or doesn't exist"
      end

      child = eval("OMF::SFA::Model::#{type}").create(resource_descr)
      parent.add_child(child)

      return child
    end

    # Releases/destroys the given resource
    #
    # @param [Resource] The actual resource we want to destroy
    # @return [Boolean] Returns true for success otherwise false
    #
    def release_resource(resource)
      debug "release_resource: resource-> '#{resource.to_json}'"
      unless resource.is_a? OMF::SFA::Model::Resource
        raise "Expected Resource but got '#{resource.inspect}'"
      end

      # resource.leases.each do |l|
      #   time = Time.now
      #   if (l.valid_until.utc <= time.utc)
      #     l.status = "past"
      #   else
      #     l.status = "cancelled"
      #   end
      #   l.save
      # end

      resource = resource.destroy
      raise "Failed to destroy resource" unless resource
      resource
    end

    # Accept or reject the reservation of the component
    #
    # @param [Lease] lease contains the corresponding reservation window
    # @param [Component] component is the resource we want to reserve
    # @return [Boolean] returns true or false depending on the outcome of the request
    #
    def lease_component(lease, component)
      # Parent Component provides itself(children) so many times as the accepted leases on it.
      debug "lease_component: lease:'#{lease.name}' to component:'#{component.name}'"

      parent = component.parent

      if component_available?(component, lease.valid_from, lease.valid_until)
        lease.status = "accepted"
        parent.add_lease(lease)   
        component.add_lease(lease)
        lease.save

        true
      else
        false
      end
    end

    # Check if a component is available in a specific timeslot or not.
    #
    # @param [OMF::SFA::Component] the component
    # @param [Time] the starting point of the timeslot
    # @param [Time] the ending point of the timeslot
    # @return [Boolean] true if it is available, false if it is not
    #
    def component_available?(component, start_time, end_time)
      return component.available unless component.exclusive
      return true if OMF::SFA::Model::Lease.all.empty?

      parent = component.parent
      leases = OMF::SFA::Model::Lease.where(components: [parent], status: ['active', 'accepted']){((valid_from >= start_time) & (valid_from <= end_time)) |
                                                                  ((valid_from <= start_time) & (valid_until >= start_time))}

      leases.nil? || leases.empty?
    end

    # Resolve an unbound query.
    #
    # @param [Hash] a hash containing the query.
    # @return [Hash] a
    #
    def resolve_query(query, am_manager, authorizer)
      debug "resolve_query: #{query}"

      @@mapping_hook.resolve(query, am_manager, authorizer)
    end

    # It returns the default account, normally used for admin account.
    #
    # @return [Account] returns the default account object
    #
    def get_nil_account()
      @nil_account
    end

    def initialize(opts = {})
      @nil_account = OMF::SFA::Model::Account.find_or_create(:name => '__default__') do |a|
        a.valid_until = Time.now + 1E10
        user = OMF::SFA::Model::User.find_or_create({:name => 'root', :urn => "urn:publicid:IDN+#{OMF::SFA::Model::Constants.default_domain}+user+root"})
        user.add_account(a)
      end

      if (mopts = opts[:mapping_submodule]) && (opts[:mapping_submodule][:require]) && (opts[:mapping_submodule][:constructor])
        require mopts[:require] if mopts[:require]
        unless mconstructor = mopts[:constructor]
          raise "Missing PDP provider declaration."
        end
        @@mapping_hook = eval(mconstructor).new(opts)
      else
        debug "Loading default Mapping Submodule."
        require 'omf-sfa/am/mapping_submodule'
        @@mapping_hook = MappingSubmodule.new(opts)
      end
      #@am_liaison = OMF::SFA::AM::AMLiaison.new
    end

  end # AMScheduler

end # OMF::SFA::AM
