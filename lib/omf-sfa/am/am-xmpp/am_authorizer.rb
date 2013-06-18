require 'omf_common/lobject'
require 'omf-sfa/am/default_authorizer'
require 'omf-sfa/am/user_credential'
require 'omf-sfa/resource'

module OMF::SFA::AM::XMPP

  #include OMF::Common

  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class AMAuthorizer < OMF::SFA::AM::DefaultAuthorizer

    # @!attribute [r] account
    #        @return [OAccount] The account associated with this instance
    attr_reader :account

    # @!attribute [r] project
    #        @return [OProject] The project associated with this account
    attr_reader :project

    # @!attribute [r] user
    #        @return [User] The user associated with this membership
    attr_reader :user


    # Create an instance from the information provided by the certificate
    #
    # @param [OpenSSL::X509::Certificate] The provided certificate
    # @param [AmManager] AM Manager for retrieving AM context
    #
    def self.create_for_xmpp_request(certificate, am_manager)

      begin
        raise "Missing peer cert" unless certificate
        peer = OMF::SFA::AM::UserCredential.unmarshall(certificate)
      end
      debug "Requester: #{peer.subject} :: #{peer.user_urn}"

      unless peer.valid_at?
        OMF::SFA::AM::InsufficientPrivilegesException.new "The certificate has expired or not valid yet. Check the dates."
      end

      if peer.user_uuid
        user = am_manager.find_or_create_user(:uuid => peer.user_uuid)
      elsif peer.user_urn
        user = am_manager.find_or_create_user(:urn => peer.user_urn)
      else
        raise OMF::SFA::AM::InsufficientPrivilegesException.new "The certificate doesn't contain user information"
      end

      self.new(user, peer, am_manager)
    end


    ##### ACCOUNT

    def can_renew_account?(account, expiration_time)
      debug "Check permission 'can_renew_account?' (#{account == @account}, #{@permissions[:can_renew_account?]}, #{@user_cert.valid_at?(expiration_time)})"
      unless account == @account &&
        @permissions[:can_renew_account?] &&
        @user_cert.valid_at?(expiration_time) # not sure if this is the right check
        raise OMF::SFA::AM::InsufficientPrivilegesException.new("Can't renew account after the expiration of the credentials")
      end
    end

    ##### RESOURCE

    def can_release_resource?(resource)
      unless resource.account == @account && @permissions[:can_release_resource?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
    end

    ##### LEASE

    def can_release_lease?(lease)
      unless lease.account == @account && @permissions[:can_release_lease?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
    end

    def can_modify_lease?(lease)
      unless lease.account == @account && @permissions[:can_modify_lease?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
    end

    protected

    def initialize(user, user_cert, am_manager)
      super()

      @user = user
      @user_cert = user_cert

      #ACCOUNT
      @permissions[:can_create_account?] = false
      @permissions[:can_view_account?] = true
      @permissions[:can_renew_account?] = true
      @permissions[:can_close_account?] = false

      #RESOURCE
      @permissions[:can_create_resource?] = true
      @permissions[:can_view_resource?] = true
      @permissions[:can_release_resource?] = true

      #LEASE
      @permissions[:can_view_lease?] = true
      @permissions[:can_modify_lease?] = true
      @permissions[:can_release_lease?] = true



      debug "Have permission '#{@permissions.inspect}'"

      # TODO: we should call the am_manager method with a root authorizer
      # For the moment 1 account = 1 user. We need to come up with a solution for describing slices and users within FRCP A/A mechanisms
      @account = OMF::SFA::Resource::OAccount.first_or_create(:urn => user.urn)
      project = OMF::SFA::Resource::Project.create
      @account.project = project
      @account.valid_until = @user_cert.not_after
      @account.save

      if @account.closed?
        if @permissions[:can_create_account?]
          @account.closed_at = nil
        else
          raise OMF::SFA::AM::InsufficientPrivilegesException.new("You don't have the privilege to enable a closed account")
        end
      end
      # XXX: decide where/when to create the Project. Right now we are creating it along with the account in the above method
      @project = @account.project

    end

  end #Class
end #Module
