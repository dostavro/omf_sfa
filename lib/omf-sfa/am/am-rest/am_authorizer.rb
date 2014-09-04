# require 'omf_common/lobject'
require 'omf-sfa/am/default_authorizer'
require 'omf-sfa/am/user_credential'
# require 'omf-sfa/am/privilege_credential'

module OMF::SFA::AM::Rest

  include OMF::Common

  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class AMAuthorizer < OMF::SFA::AM::DefaultAuthorizer

    # @!attribute [r] account
    #        @return [Account] The account associated with this instance
    attr_reader :account

    # @!attribute [r] project
    #        @return [OProject] The project associated with this account
    attr_reader :project

    # @!attribute [r] user
    #        @return [User] The user associated with this membership
    attr_reader :user


    def self.create_for_rest_request(authenticated, certificate, account, am_manager)

      if authenticated
        raise OMF::SFA::AM::InsufficientPrivilegesException.new("Missing peer cert") unless certificate
        peer = OMF::SFA::AM::UserCredential.unmarshall(certificate)
        
        debug "Requester: #{peer.subject} :: #{peer.user_urn}"

        unless peer.valid_at?
          OMF::SFA::AM::InsufficientPrivilegesException.new "The certificate has expired or not valid yet. Check the dates."
        end

        user_descr = {}
        user_descr.merge!({uuid: peer.user_uuid}) unless peer.user_uuid.nil?
        user_descr.merge!({urn: peer.user_urn}) unless peer.user_urn.nil?
        raise OMF::SFA::AM::InsufficientPrivilegesException.new "URN and UUID are missing." if user_descr.empty?

        begin
          user = am_manager.find_user(user_descr)
        rescue OMF::SFA::AM::UnavailableResourceException
          raise OMF::SFA::AM::InsufficientPrivilegesException.new "User: '#{user_descr}' does not exist"
        end

        self.new(account, user, am_manager)
      else
        self.new(nil, nil, am_manager)
      end
    end


    ##### ACCOUNT

    def can_view_account?(account)
      debug "Check permission 'can_view_account?' (#{account == @account}, #{@permissions[:can_view_account?]})"
      return true if @account == @am_manager._get_nil_account

      unless @permissions[:can_view_account?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      @user.get_all_accounts.each do |acc|
        return true if acc == account
      end
      raise OMF::SFA::AM::InsufficientPrivilegesException.new
    end

    def can_renew_account?(account, expiration_time)
      debug "Check permission 'can_renew_account?' (#{account == @account}, #{@permissions[:can_renew_account?]})"
      unless (account == @account && @permissions[:can_renew_account?]) || @account == @am_manager._get_nil_account
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    def can_close_account?(account)
      debug "Check permission 'can_close_account?' (#{account == @account}, #{@permissions[:can_close_account?]})"
      unless (account == @account && @permissions[:can_close_account?]) || @account == @am_manager._get_nil_account
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    ##### RESOURCE

    def can_create_resource?(resource, type)
      type = type.downcase
      debug "Check permission 'can_create_resource?' (#{type == 'lease'}, #{@permissions[:can_create_resource?]})"
      unless @account == @am_manager._get_nil_account || (type == 'lease' && @permissions[:can_create_resource?]) 
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    ##### LEASE

    def can_modify_lease?(lease)
      debug "Check permission 'can_modify_lease?' (#{@account == lease.account}, #{@permissions[:can_modify_lease?]})"
      unless (@account == lease.account && @permissions[:can_modify_lease?]) || @account == @am_manager._get_nil_account
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    def can_release_lease?(lease)
      debug "Check permission 'can_release_lease?' (#{@account == lease.account}, #{@permissions[:can_release_lease?]})"
      unless (@account == lease.account && @permissions[:can_release_lease?]) || @account == @am_manager._get_nil_account
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    protected

    def initialize(account, user, am_manager)
      debug "Initialize for account: #{account} and user: #{user.inspect})"
      @user = user
      @am_manager = am_manager

      if @user.nil?
        permissions = {
          can_create_account?:   false,
          can_view_account?:     false,
          can_renew_account?:    false,
          can_close_account?:    false,
          # RESOURCE
          can_create_resource?:  false,
          can_modify_resource?:  false,
          can_view_resource?:    true,
          can_release_resource?: false,
          # LEASE
          can_view_lease?:       true,
          can_modify_lease?:     false,
          can_release_lease?:    false
        }
        super(permissions)
      else
        super()
        # @account = am_manager.find_account({name: account}, self) if account
        @account = OMF::SFA::Resource::Account.first({name: account}) if account
        @account = @user.get_first_account if @account.nil?
        if @account.closed?
          raise OMF::SFA::AM::InsufficientPrivilegesException.new("The account '#{account}' is closed.")
        end

        @project = @account.project
        unless @user.has_nil_account?(am_manager) || @project.users.include?(@user)
          raise OMF::SFA::AM::InsufficientPrivilegesException.new("The user '#{@user.name}' does not belong to the account '#{account}'")
        end

        if @account == am_manager._get_nil_account
          @permissions.each { |p| p = true } 
        else
          @permissions = {
            can_create_account?:   false,
            can_view_account?:     true,
            can_renew_account?:    true,
            can_close_account?:    true,
            # RESOURCE
            can_create_resource?:  true,
            can_modify_resource?:  false,
            can_view_resource?:    true,
            can_release_resource?: false,
            # LEASE
            can_view_lease?:       true,
            can_modify_lease?:     true,
            can_release_lease?:    true
          }
        end
      end
    end

  end # class
end # module
