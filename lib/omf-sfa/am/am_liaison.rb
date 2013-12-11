require 'omf_common'
require 'omf-sfa/am/am_manager'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class AMLiaison < OMF::Common::LObject

    include OmfCommon

    attr_accessor :comm
    @leases = {}

    def initialize
      EM.next_tick do
        OmfCommon.comm.on_connected do |comm|
          puts "AMLiaison ready."
        end
      end
    end

    def create_account(account)
      debug "create_account: '#{account.inspect}'"

      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.create(:user, hrn: 'newuser', username: account.name) do |reply_msg|
            if reply_msg.success?
              user = reply_msg.resource

              user.on_subscribed do
                #info ">>> Connected to newly created user #{reply_msg[:hrn]}(id: #{reply_msg[:res_id]})"

                user.on_message do |m|

                  if m.operation == :inform
                    if m.read_content("itype").eql?('STATUS')
                      #info "#{m.inspect}"
                      if m.read_property("status_type") == 'APP_EVENT'
                        #puts "Succesfully created user"
                        am_cert = OmfCommon::Auth::CertificateStore.instance.cert_for(OmfCommon.comm.local_topic.address)
                        # urn:publicid:IDN+omf:nitos+slice+alice
                        puts "ACCOUNT #{account.valid_until}"
                        duration = account.valid_until.to_i - Time.now.to_i
                        user_cert = am_cert.create_for(account.urn, account.name, 'slice', 'omf', duration, m.read_property('pub_key'))
                        user.configure(cert: user_cert.to_pem) do |reply|
                          if reply.success?
                            release_proxy(user_rc, user)
                          else
                            error "Configuration of the certificate failed - #{reply[:reason]}"
                          end
                        end
                      end
                    end
                  end

                end

              end
            else
              error ">>> Resource creation failed - #{reply_msg[:reason]}"
            end
          end
        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end
    end

    def close_account(account)
      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.configure(deluser: {username: account.name}) do |msg|
            if msg.success?
              info "Account: '#{account.inspect}' successfully deleted."
            else
              error "Account: '#{account.inspect}' couldn't deleted."
            end
          end

        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end
    end

    def configure_keys(keys, account)
      debug "configure_keys: keys:'#{keys.inspect}', account:'#{account.inspect}'"

      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.create(:user, hrn: 'existing_user', username: account.name) do |reply_msg|
            if reply_msg.success?
              u = reply_msg.resource

              u.on_subscribed do

                u.configure(auth_keys: keys) do |reply|
                  if reply.success?
                    release_proxy(user_rc, u)
                  else
                    error "Configuration of the public keys failed - #{reply[:reason]}"
                  end
                end
              end
            else
              error ">>> Resource creation failed - #{reply_msg[:reason]}"
            end
          end
        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end
    end


    # It will send the corresponding create messages to the components contained
    # in the lease when the lease is about to start. At the end of the
    # lease the corresponding release messages will be sent to the components.
    #
    # @param [Lease] lease Contains the lease information "valid_from" and
    #                 "valid_until" along with the reserved components
    #
    def enable_lease(lease, component)
      debug "enable_lease: lease: '#{lease.inspect}' component: '#{component.inspect}'"

      @leases ||= {}

      OmfCommon.comm.subscribe(component.name) do |resource|
        unless resource.error?

          create_timer = EventMachine::Timer.new(lease[:valid_from] - Time.now) do
            @leases[lease] = {} unless @leases[lease]
            @leases[lease] = { component.id => {:start => create_timer} }

            #create_resource(resource, lease, :node, {hrn: component.name, uuid: component.uuid})
            create_resource(resource, lease, component)
          end
        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{resource.inspect}'"
          #error res.inspect
        end
      end
    end

    def create_resource(resource, lease, component)
      #resource.create(type, hrn: component.name, uuid: component.uuid) do |reply_msg|
      resource.create(component.resource_type.to_sym, hrn: component.name, uuid: component.uuid) do |reply_msg|
        if reply_msg.success?
          new_res = reply_msg.resource

          new_res.on_subscribed do
            info ">>> Connected to newly created node #{reply_msg[:hrn]}(id: #{reply_msg[:res_id]})"
            # Then later on, we will ask res to release this component.
            #
            release_resource(resource, new_res, lease, component)
          end
        else
          error ">>> Resource creation failed - #{reply_msg[:reason]}"
        end
      end
    end

    def release_resource(resource, new_res, lease, component)

      release_timer = EventMachine::Timer.new(lease[:valid_until] - Time.now) do
        #OmfCommon.eventloop.after(lease[:valid_from] - Time.now) do
        @leases[lease][component.id] = {:end => release_timer}
        resource.release(new_res) do |reply_msg|
          info "Node #{reply_msg[:res_id]} released"
          @leases[lease].delete(component.id)
          @leases.delete(lease) if @leases[lease].empty?
        end
      end
    end


    #def release_lease(resource)

    #  resource_topic = @comm.get_topic(resource.name)

    #  raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{resource.inspect}'" unless resource_topic

    #end

    private

    def release_proxy(parent, child)
      parent.release(child) do |reply_msg|
        unless reply_msg.success?
          error "Release of the proxy #{child} failed - #{reply_msg[:reason]}"
        end
      end
    end


  end # AMLiaison
end # OMF::SFA::AM

