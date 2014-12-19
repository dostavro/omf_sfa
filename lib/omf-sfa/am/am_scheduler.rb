
require 'omf_common/lobject'
# require 'omf-sfa/models'
# require 'omf-sfa/resource/comp_group'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_liaison'
require 'active_support/inflector'



module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Common::LObject

    @@mapping_hook = nil

    # Create a resource of specific type given its description in a hash. If the type
    # or the resource is physical then we create a clone of itself and assign it to
    # the user who asked for it (conceptually a physical resource even though it is exclusive,
    # is never given to the user but instead we provide him a clone of the resource).
    # If the type is a 'lease' then we normally create a lease object.
    #
    # @param [Hash] resource_descr contains the properties of the new resource
    # @param [String] The type of the resource we want to create
    # @param [Hash] oproperties is a hash with all the OProperty values of the new resource
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] Returns the created resource
    #
    def create_resource(resource_descr, type_to_create, oproperties, authorizer)
      debug "create_resource: resource_descr:'#{resource_descr}' type_to_create:'#{type_to_create}' oproperties:'#{oproperties}' authorizer:'#{authorizer.inspect}'"
      if type_to_create.downcase.eql?('lease')

        resource_descr[:resource_type] = type_to_create
        resource_descr[:account] = authorizer.account
        lease = OMF::SFA::Model::Lease.create(resource_descr)
        lease.valid_from = oproperties[:valid_from]
        lease.valid_until = oproperties[:valid_until]
        raise UnavailableResourceException.new "Cannot create '#{resource_descr.inspect}'" unless lease.save
        lease
      else
        desc = resource_descr.dup
        desc[:account] = get_nil_account()

        type = type_to_create.camelize

        base_resource = eval("OMF::SFA::Model::#{type}").first(desc)

        if base_resource.nil? || !base_resource.available
          raise UnknownResourceException.new "Resource '#{desc.inspect}' is not available or doesn't exist"
        end

        # create a clone
        values = base_resource.values
        values.delete(:id)
        vr = eval("OMF::SFA::Model::#{type}").create(values)

        vr.account = authorizer.account
        # vr.provided_by = base_resource
        # vr.save

        base_resource.add_child(vr)
        # base_resource.provides << vr
        # base_resource.save

        return vr
      end
    end

    # Releases/destroys the given resource
    #
    # @param [OResource] The actual resource we want to destroy
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Boolean] Returns true for success otherwise false
    #
    def release_resource(resource, authorizer)
      debug "release_resource: resource-> '#{resource.to_json}'"
      unless resource.is_a? OMF::SFA::Model::Resource
        raise "Expected Resource but got '#{resource.inspect}'"
      end

      base = resource.parent

      unless resource.leases.empty?
        base.leases.each do |l|
          if (l.id == resource.leases.first.id)
            time = Time.now
            if (l.valid_until.utc <= time.utc)
              l.status = "past"
            else
              l.status = "cancelled"
            end
          end
        end
      end
      resource = resource.destroy
      raise "Failed to destroy resource" unless resource
      resource
    end

    # Accept or reject the reservation of the component
    #
    # @param [Lease] lease contains the corresponding reservation window
    # @param [OComponent] component is the resource we want to reserve
    # @return [Boolean] returns true or false depending on the outcome of the request
    #
    def lease_component(lease, component)
      # Basic Component provides itself(clones) so many times as the accepted leases on it.
      debug "lease_component: lease:'#{lease.name}' to component:'#{component.name}'"

      base = component.parent
      base.leases.each do |l|
        if (lease.valid_from.utc >= l.valid_until.utc || lease.valid_until.utc <= l.valid_from.utc)
          #all ok, do nothing
        elsif (lease.valid_from.utc <= l.valid_from.utc && lease.valid_until.utc > l.valid_from.utc)#overlapping time
          raise UnavailableResourceException.new "Cannot lease '#{component.name}', because it is unavailable for the requested time."
        elsif (lease.valid_from.utc >= l.valid_from.utc && lease.valid_from.utc <= l.valid_until.utc)#overlapping time
          raise UnavailableResourceException.new "Cannot lease '#{component.name}', because it is unavailable for the requested time."
        end
      end
      lease.status = "accepted"
      base.add_lease(lease)
      # base.save
      component.add_lease(lease)
      # component.save
      #@am_liaison.enable_lease(lease, component)
      return true
    end

    # Check if a resource is available in a specific timeslot or not.
    #
    # @param [OMF::SFA::OResource] the resource
    # @param [Time] the starting point of the timeslot
    # @param [Time] the ending point of the timeslot
    # @return [Boolean] true if it is available, false if it is not
    #
    def component_available?(resource, valid_from, valid_until)
      return resource.available unless resource.exclusive
      resource.leases.each do |l|
        if (valid_from.utc >= l.valid_until.utc || valid_until.utc < l.valid_from.utc)
          next
        else
          return false
        end
      end
      true
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

  end # OMFManager

end # OMF::SFA::AM
