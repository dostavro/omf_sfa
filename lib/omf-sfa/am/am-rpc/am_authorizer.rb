require 'omf_common/lobject'
require 'omf-sfa/am/default_authorizer'
require 'omf-sfa/am/user_credential'
require 'omf-sfa/am/privilege_credential'

module OMF::SFA::AM::RPC

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


    # @!attribute [r] certificate
    #        @return [Hash] The certificate associated with this caller
#    attr_reader :certificate


    # Create an instance from the information
    # provided by the rack's 'req' object.
    #
    # @param [Rack::Request] Request provided by the Rack API
    # @param [AbstractAmManager#get_account] AM Manager for retrieving AM context
    #
    def self.create_for_sfa_request(account_urn, credentials, request, am_manager)

      begin
        raise "Missing peer cert" unless cert_s = request.env['rack.peer_cert']
        peer = OMF::SFA::AM::UserCredential.unmarshall(cert_s)
      end
      debug "Requester: #{peer.subject} :: #{peer.user_urn}"

      raise OMF::SFA::AM::InsufficientPrivilegesException.new "Credentials are missing." if credentials.nil? || credentials.empty?

      unless peer.valid_at?
        OMF::SFA::AM::InsufficientPrivilegesException.new "The certificate has expired or not valid yet. Check the dates."
      end

      user_descr = {}
      user_descr.merge!({uuid: peer.user_uuid}) unless peer.user_uuid.nil?
      user_descr.merge!({urn: peer.user_urn}) unless peer.user_urn.nil?
      raise OMF::SFA::AM::InsufficientPrivilegesException.new "URN and UUID are missing." if user_descr.empty?
      user = am_manager.find_or_create_user(user_descr, [])

      creds = credentials.map do |cs|
        cs = OMF::SFA::AM::PrivilegeCredential.unmarshall(cs)
        cs.tap do |c|
          unless c.valid_at?
            OMF::SFA::AM::InsufficientPrivilegesException.new "The credentials have expired or not valid yet. Check the dates."
          end
        end
      end


      self.new(account_urn, peer, creds, am_manager, user)
    end


    ##### ACCOUNT

    def can_renew_account?(account, expiration_time)
      debug "Check permission 'can_renew_account?' (#{account.id == @account.id}, #{@permissions[:can_renew_account?]}, #{@user_cred.valid_at?(expiration_time)})"
      unless account.id == @account.id &&
          @permissions[:can_renew_account?] &&
          @user_cred.valid_at?(expiration_time) # not sure if this is the right check
        raise OMF::SFA::AM::InsufficientPrivilegesException.new("Can't renew account after the expiration of the credentials")
      end
      true
    end

    ##### RESOURCE

    def can_release_resource?(resource)
      unless resource.account.id == @account.id && @permissions[:can_release_resource?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new
      end
      true
    end

    def create_account_name_from_urn(urn)
      max_size = 32
      gurn = OMF::SFA::Model::GURN.create(urn, :type => "OMF::SFA::Resource::Account")
      domain = gurn.domain.gsub(":", '.')
      acc_name = "#{domain}.#{gurn.short_name}"
      return acc_name if acc_name.size <= max_size

      domain = gurn.domain
      authority = domain.split(":").first.split(".").first
      subauthority = domain.split(":").last
      acc_name = "#{authority}.#{subauthority}.#{gurn.short_name}"
      return acc_name if acc_name.size <= max_size

      acc_name = "#{subauthority}.#{gurn.short_name}"
      if acc_name.size <= max_size
        if account_name_exists_for_another_urn?(acc_name, urn)
          nof_chars_to_delete = "#{authority}.#{subauthority}.#{gurn.short_name}".size - max_size 
          acc_name = ""
          acc_name += "#{authority[0..-(nof_chars_to_delete / 2 + 1).to_i]}." # +1 for the dot in the end
          acc_name +=  "#{subauthority[0..-(nof_chars_to_delete / 2 + 1).to_i]}.#{gurn.short_name}"
          acc_name = acc_name.sub('..','.')
          return acc_name unless account_name_exists_for_another_urn?(acc_name, urn)
        else
          return acc_name 
        end
      end

      acc_name = gurn.short_name
      return acc_name if acc_name.size <= max_size && !account_name_exists_for_another_urn?(acc_name, urn)
      raise OMF::SFA::AM::FormatException.new "Slice urn is too long, account '#{acc_name}' cannot be generated."
    end

    def account_name_exists_for_another_urn?(name, urn)
      acc = OMF::SFA::Model::Account.first(name: name)
      return true if acc && acc.urn != urn
      false
    end

    protected

    def initialize(account_urn, user_cert, credentials, am_manager, user)
      super()

      @user_cert = user_cert
      @user = user

      # NOTE: We only look at the first cred
      credential = credentials[0]
      debug "cred: #{credential.inspect}"
      unless (user_cert.user_urn == credential.user_urn)
        raise OMF::SFA::AM::InsufficientPrivilegesException.new "User urn mismatch in certificate and credentials. cert:'#{user_cert.user_urn}' cred:'#{credential.user_urn}'"
      end

      @user_cred = credential


      if credential.type == 'slice'
        if credential.privilege?('*')
          @permissions[:can_create_account?] = true
          @permissions[:can_view_account?] = true
          @permissions[:can_renew_account?] = true
          @permissions[:can_close_account?] = true
        else
          @permissions[:can_create_account?] = credential.privilege?('control')
          @permissions[:can_view_account?] = credential.privilege?('info')
          @permissions[:can_renew_account?] = credential.privilege?('refresh')
          @permissions[:can_close_account?] = credential.privilege?('control')
        end
      end

      if credential.privilege?('*')
        @permissions[:can_create_resource?] = true
        @permissions[:can_view_resource?] = true
        @permissions[:can_release_resource?] = true

        @permissions[:can_view_lease?] = true
        @permissions[:can_modify_lease?] = true
        @permissions[:can_release_lease?] = true
      else
        @permissions[:can_create_resource?] = credential.privilege?('refresh')
        @permissions[:can_view_resource?] = credential.privilege?('info')
        @permissions[:can_release_resource?] = credential.privilege?('refresh')

        @permissions[:can_view_lease?] = credential.privilege?('info')
        @permissions[:can_modify_lease?] = credential.privilege?('refresh')
        @permissions[:can_release_lease?] = credential.privilege?('refresh')
      end


      debug "Have permission '#{@permissions.inspect}'"

      unless account_urn.nil?
        unless account_urn.eql?(credential.target_urn)
          raise OMF::SFA::AM::InsufficientPrivilegesException.new "Slice urn mismatch in XML call and credentials"
        end

        acc_name = create_account_name_from_urn(account_urn)

        @account = am_manager.find_or_create_account({:urn => account_urn, :name => acc_name}, self)
        # if @account.valid_until != @user_cred.valid_until
          # @account.valid_until = @user_cred.valid_until
          debug "Renewing account '#{@account.name}' until '#{@user_cred.valid_until}'"
          am_manager.renew_account_until(@account, @user_cred.valid_until, self)
        # end
        if @account.closed?
          if @permissions[:can_create_account?]
            @account.closed_at = nil
          else
            raise OMF::SFA::AM::InsufficientPrivilegesException.new("You don't have the privilege to enable a closed account")
          end
        end
        @account.add_user(@user) unless @account.users.include?(@user)
        @account.save
      end
    end
  end
end
