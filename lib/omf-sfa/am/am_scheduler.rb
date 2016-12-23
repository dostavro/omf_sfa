
require 'omf_common/lobject'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_liaison'
require 'active_support/inflector'
require 'rufus-scheduler'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Common::LObject

    @@mapping_hook = nil

    attr_reader :event_scheduler, :options

    # Create a resource of specific type given its description in a hash. We create a clone of itself 
    # and assign it to the user who asked for it (conceptually a physical resource even though it is exclusive,
    # is never given to the user but instead we provide him a clone of the resource).
    #
    # @param [Hash] resource_descr contains the properties of the new resource. Must contain the account_id.
    # @param [String] The type of the resource we want to create
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

      child = parent.clone 

      ac = OMF::SFA::Model::Account[resource_descr[:account_id]] #search with id
      child.account = ac
      child.status = "unknown"
      child.save
      parent.add_child(child)

      child
    end

    # Find al leases if no +account+ and +status+ is given
    #
    # @param [Account] filter the leases by account
    # @param [Status] filter the leases by their status ['pending', 'accepted', 'active', 'past', 'cancelled']
    # @return [Lease] The requested leases
    #
    def find_all_leases(account = nil, status = ['pending', 'accepted', 'active', 'past', 'cancelled'])
      debug "find_all_leases: account: #{account.inspect} status: #{status}"
      if account.nil?
        leases = OMF::SFA::Model::Lease.where(status: status)
      else
        leases = OMF::SFA::Model::Lease.where(account_id: account.id, status: status)
      end
      leases.to_a
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

      resource = resource.destroy
      raise "Failed to destroy resource" unless resource
      resource
    end

    # cancel +lease+
    #
    # This implementation simply frees the lease record
    # and destroys any child components if attached to the lease
    #
    # @param [Lease] lease to release
    #
    def release_lease(lease)
      debug "release_lease: lease:'#{lease.inspect}'"
      unless lease.is_a? OMF::SFA::Model::Lease
        raise "Expected Lease but got '#{lease.inspect}'"
      end

      lease.components.each do |c|
          c.destroy unless c.parent_id.nil? # Destroy all the children and leave the parent intact
      end
      
      if lease.status == 'active'
        @liaison.on_lease_end(lease)
      end

      lease.valid_until <= Time.now ? lease.status = "past" : lease.status = "cancelled"
      l = lease.save
      delete_lease_events_from_event_scheduler(lease) if l
      l
    end

    # delete +lease+
    #
    # This implementation simply frees the lease record
    # and destroys any child components if attached to the lease
    #
    # @param [Lease] lease to release
    #
    def delete_lease(lease)
      debug "delete_lease: lease:'#{lease.inspect}'"
      unless lease.is_a? OMF::SFA::Model::Lease
        raise "Expected Lease but got '#{lease.inspect}'"
      end
      lease.components.each do |c|
        c.destroy unless c.parent_id.nil? # Destroy all the children and leave the parent intact
      end

      lease.destroy
      true
    end

    # update +lease+
    #
    # This will check if the lease can be updated and then update it accordingly
    # this should be used to update valid_from and valid_until only, other properties can be updated
    # like any other resource
    #
    # @param [Lease] lease to release
    # @param [Hash]  properties to be modified
    #
    def update_lease(lease, description)
      debug "modify_lease: lease:'#{lease.inspect}' - #{description.inspect}"
      unless lease.is_a? OMF::SFA::Model::Lease
        raise "Expected Lease but got '#{lease.inspect}'"
      end
      description[:valid_until] = Time.parse(description[:valid_until]) if description[:valid_until] && description[:valid_until].kind_of?(String)
      description[:valid_from] = Time.parse(description[:valid_from]) if description[:valid_from] && description[:valid_from].kind_of?(String)

      if (description[:valid_until] && description[:valid_until] < lease.valid_until) || (description[:valid_from] && description[:valid_from] > lease.valid_from)
        lease.update(description)
        return
      elsif description[:valid_until] && description[:valid_from]
        timeslot_from1 = description[:valid_from]
        timeslot_until1 = lease.valid_from
        timeslot_from2 = lease.valid_until
        timeslot_until2 = description[:valid_until]

        lease.components.each do |comp|
          next unless comp.parent.nil? # only unmanaged components should be checked
          unless component_available?(comp, timeslot_from1, timeslot_until1)
            raise UnavailableResourceException.new "Resource '#{comp.name}' is not available for the requested timeslot."
          end
          unless component_available?(comp, timeslot_from2, timeslot_until2)
            raise UnavailableResourceException.new "Resource '#{comp.name}' is not available for the requested timeslot."
          end
        end
        lease.update(description)
        return
      elsif description[:valid_from]
        timeslot_from = description[:valid_from]
        timeslot_until = lease.valid_from
      elsif description[:valid_until]
        timeslot_from = lease.valid_until
        timeslot_until = description[:valid_until]
      else
        raise "Cannot update lease without valid_from or valid_until in the description."
      end 

      lease.components.each do |comp|
        next unless comp.parent.nil? # only unmanaged components should be checked
        unless component_available?(comp, timeslot_from, timeslot_until)
          raise UnavailableResourceException.new "Resource '#{comp.name}' is not available for the requested timeslot."
        end
      end

      lease.update(description)

      lease
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

      return false unless @@am_policies.valid?(lease, component)
      # @@am_policies.validate(lease, component)

      if component_available?(component, lease.valid_from, lease.valid_until)
        time = Time.now
        lease.status = time > lease.valid_until ? "past" : time <= lease.valid_until && time >= lease.valid_from ? "active" : "accepted" 
        parent.add_lease(lease)   
        component.add_lease(lease)
        lease.save
        parent.save
        component.save
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
      return false unless component.available
      return true if OMF::SFA::Model::Lease.all.empty?

      parent = component.account == get_nil_account() ? component : component.parent

      leases = OMF::SFA::Model::Lease.where(components: [parent], status: ['active', 'accepted']){((valid_from >= start_time) & (valid_from < end_time)) | ((valid_from <= start_time) & (valid_until > start_time))}

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

    attr_accessor :liaison, :event_scheduler

    def initialize(opts = {})
      @options = opts
      @nil_account = OMF::SFA::Model::Account.find_or_create(:name => '__default__') do |a|
        a.valid_until = Time.now + 1E10
        user = OMF::SFA::Model::User.find_or_create({:name => 'root', :urn => "urn:publicid:IDN+#{OMF::SFA::Model::Constants.default_domain}+user+root"})
        user.add_account(a)
      end

      if (mopts = opts[:mapping_submodule]) && (opts[:mapping_submodule][:require]) && (opts[:mapping_submodule][:constructor])
        require mopts[:require] if mopts[:require]
        raise "Missing Mapping Submodule provider declaration." unless mconstructor = mopts[:constructor]
        @@mapping_hook = eval(mconstructor).new(opts)
      else
        debug "Loading default Mapping Submodule."
        require 'omf-sfa/am/mapping_submodule'
        @@mapping_hook = MappingSubmodule.new(opts)
      end

      if (popts = opts[:am_policies]) && (opts[:am_policies][:require]) && (opts[:am_policies][:constructor])
        require popts[:require] if popts[:require]
        raise "Missing AM Policies Module provider declaration." unless pconstructor = popts[:constructor]
        @@am_policies = eval(pconstructor).new(opts)
      else
        debug "Loading default Policies Module."
        require 'omf-sfa/am/am_policies'
        @@am_policies = AMPolicies.new(opts)
      end
      #@am_liaison = OMF::SFA::AM::AMLiaison.new
    end

    def initialize_event_scheduler
      debug "initialize_event_scheduler"
      @event_scheduler = Rufus::Scheduler.new

      leases = find_all_leases(nil, ['pending', 'accepted', 'active'])
      leases.each do |lease|
        add_lease_events_on_event_scheduler(lease)
      end

      list_all_event_scheduler_jobs
    end

    def am_policies=(policy)
      @@am_policies = policy
    end

    def am_policies
      @@am_policies
    end

    def add_lease_events_on_event_scheduler(lease)
      debug "add_lease_events_on_event_scheduler: lease: #{lease.inspect}"
      t_now = Time.now
      l_uuid = lease.uuid
      if t_now >= lease.valid_until
        release_lease(lease)
        return
      end
      if t_now >= lease.valid_from # the lease is active - create only the on_lease_end event
        lease.status = 'active'
        lease.save
        @event_scheduler.in('0.1s', tag: "#{l_uuid}_start") do
          lease = OMF::SFA::Model::Lease.first(uuid: l_uuid)
          break if lease.nil?
          @liaison.on_lease_start(lease)
        end
      else
        @event_scheduler.at(lease.valid_from, tag: "#{l_uuid}_start") do
          lease = OMF::SFA::Model::Lease.first(uuid: l_uuid)
          break if lease.nil?
          lease.status = 'active'
          lease.save
          @liaison.on_lease_start(lease)
        end
      end
      @event_scheduler.at(lease.valid_until, tag: "#{l_uuid}_end") do
        lease = OMF::SFA::Model::Lease.first(uuid: l_uuid) 
        lease.status = 'past'
        lease.save
        @liaison.on_lease_end(lease)
      end
    end

    def update_lease_events_on_event_scheduler(lease)
      debug "update_lease_events_on_event_scheduler: lease: #{lease.inspect}"
      delete_lease_events_from_event_scheduler(lease)
      add_lease_events_on_event_scheduler(lease)
      list_all_event_scheduler_jobs
    end

    def delete_lease_events_from_event_scheduler(lease)
      debug "delete_lease_events_on_event_scheduler: lease: #{lease.inspect}"
      uuid = lease.uuid
      job_ids = []
      @event_scheduler.jobs.each do |j|
        job_ids << j.id if j.tags.first == "#{uuid}_start" || j.tags.first == "#{uuid}_end"
      end

      job_ids.each do |jid|
        debug "unscheduling job: #{jid}"
        @event_scheduler.unschedule(jid)
      end

      list_all_event_scheduler_jobs
    end

    def list_all_event_scheduler_jobs
      debug "Existing jobs on event scheduler: "
      debug "no jobs in the queue" if @event_scheduler.jobs.empty?
      @event_scheduler.jobs.each do |j|
        debug "job: #{j.tags.first} - #{j.next_time}"
      end
    end
  end # AMScheduler
end # OMF::SFA::AM
