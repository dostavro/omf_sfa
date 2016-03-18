require 'omf_common/lobject'
require 'omf-sfa/am/am_scheduler'

module OMF::SFA::AM

  class AMPoliciesException < Exception; end
  class MaxMinutesQuotaExceededException < AMPoliciesException; end
  class MaxResourcesQuotaExceededException < AMPoliciesException; end
  class MaxTimeslotsQuotaExceededException < AMPoliciesException; end
  class QuotaExceededException < AMPoliciesException; end

  extend OMF::SFA::AM
  # This class implements the AM Policies controller
  #
  class AMPolicies < OMF::Common::LObject

    attr_accessor :policies_per_domain, :default_policy

    def initialize(opts = {})
      debug "AMPolicies Initialization: options: #{opts.inspect}"
      @config = opts[:policies].nil? ? OMF::Common::YAML.load('am_policies_conf', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:policies] : opts[:policies]
      if @config.nil?
        @enabled = false
      elsif @config[:enabled] && @config[:policies_per_domain]
        @enabled = true
        @policies_per_domain = @config[:policies_per_domain]
        @policies_per_urn    = @config[:policies_per_urn]
        @default_policy = @policies_per_domain.find {|k| k['domain'] == "DEFAULT"}
        @default_policy = {domain: 'DEFAULT', quota: {max_resources: -1, max_minutes: -1}} unless @default_policy
      else
        @enabled = false
      end
      debug "AMPolicies configuration: enabled: #{@enabled}, policies_per_domain: #{@policies_per_domain}, policies_per_urn: #{@policies_per_urn}, default_policy: #{@default_policy} "
    end

    def valid?(lease, component=nil)
      puts "valid? #{lease.inspect} : #{component.inspect}"
      validate(lease, component)
    rescue OMF::SFA::AM::QuotaExceededException
      return false
    rescue OMF::SFA::AM::MaxMinutesQuotaExceededException
      return false
    rescue OMF::SFA::AM::MaxResourcesQuotaExceededException
      return false
    rescue OMF::SFA::AM::MaxTimeslotsQuotaExceededException
      return false
    end

    def validate(lease, component=nil)
      return true unless enabled? #if policies are disabled the lease is always valid
      puts "enabled passed"
      policy = find_policy(lease.account)
      puts "policy: #{policy.inspect}"
      days = get_days_in_lease_lifespawn(lease)
      puts "days: #{days.inspect}"
      raise OMF::SFA::AM::QuotaExceededException.new 'Operation not allowed because of Quota exceeded.' if lease_exceeds_quotas?(policy, lease, component, days) 
      puts "lease_exceeds_quotas passed"
      
      days.each do |day|
        start_time = day[0]
        end_time = day[1]
        
        leases = OMF::SFA::Model::Lease.where(account_id: lease.account.id, status: ['active', 'accepted']){((valid_from >= start_time) & (valid_from < end_time)) | ((valid_until >= start_time) & (valid_until < end_time))}

        nof_comps = 0
        minutes = 0
        leases.each do |l|
          next if l.account.id != lease.account.id
          next if l.id == lease.id

          l.components.each do |comp|
            nof_comps += 1 unless comp.parent.nil?
          end
          minutes += get_lease_minutes_in_day(l, day)
        end

        minutes   += day[2]
        lease.components.each do |comp|
          nof_comps += 1 unless comp.parent.nil?
        end
        nof_comps += 1 if component
        
        raise OMF::SFA::AM::MaxMinutesQuotaExceededException.new 'Operation not allowed because of Max Minute Policy exceeded.'  if policy[:quota][:max_minutes]   != -1 && minutes   > policy[:quota][:max_minutes]
        raise OMF::SFA::AM::MaxResourcesQuotaExceededException.new 'Operation not allowed because of Max Resources Policy exceeded.' if policy[:quota][:max_resources] != -1 && nof_comps > policy[:quota][:max_resources]
      end
      true
    end

    def find_policy(account)
      policy = find_policy_for_urn(account.urn)
      return policy if policy 
      domain = OMF::SFA::Model::GURN.parse(account.urn).domain
      find_policy_for_domain(domain)
    end

    def find_policy_for_urn(urn)
      return nil if @policies_per_urn.nil?
      @policies_per_urn.find {|k| k[:urn] == urn}
    end

    def find_policy_for_domain(domain)
      if policy = @policies_per_domain.find {|k| k[:domain] == domain}
        policy
      else
        @default_policy
      end
    end

    private
    def enabled?
      @enabled
    end

    def get_days_in_lease_lifespawn(lease)
      out = []
      start_date = Time.parse("#{lease.valid_from.year}-#{lease.valid_from.month}-#{lease.valid_from.day} 00:00:00 UTC")
      end_date   = Time.parse("#{lease.valid_until.year}-#{lease.valid_until.month}-#{lease.valid_until.day} 23:59:59 UTC")
      nof_days = ((end_date - start_date) / 1.day).ceil

      if nof_days == 1
        tmp = []
        tmp[0] = start_date
        tmp[1] = end_date
        tmp[2] = ((lease.valid_until - lease.valid_from) / 60).ceil
        out << tmp
      else
        nof_days.times do |i|
          tmp = []
          tmp[0] = start_date + i.day
          tmp[1] = start_date + i.day + 1.day - 1
          if i == 0
            tmp[2] = ((tmp[1] - lease.valid_from) / 60).ceil
          elsif i == (nof_days - 1)
            tmp[2] = ((lease.valid_until - tmp[0]) / 60).ceil
          else
            tmp[2] = 24 * 60
          end
          out << tmp
        end
      end
      out
    end

    def lease_exceeds_quotas?(policy, lease, component, days)
      nof_comps = 0
      lease.components.each do |comp|
        nof_comps += 1 unless comp.parent.nil?
      end
      nof_comps = component ? nof_comps + 1 : nof_comps
      
      return true if policy[:quota][:max_resources] != -1 &&  nof_comps > policy[:quota][:max_resources]

      days.each do |day|
        return true if policy[:quota][:max_minutes] != -1 && day[2] > policy[:quota][:max_minutes]
      end
      false
    end

    def get_lease_minutes_in_day(lease, day)
      start_time = day[0]
      end_time   = day[1]
      minutes    = 0

      if lease.valid_from >= start_time && lease.valid_until <= end_time #the l is inside the day
        minutes += (lease.valid_until - lease.valid_from) / 60
      elsif lease.valid_from <= start_time && lease.valid_until <= end_time
        minutes += (lease.valid_until - lease.valid_from) / 60
      elsif lease.valid_from >= start_time && lease.valid_until >= end_time
        minutes += (lease.valid_until - lease.valid_from) / 60
      else
        minutes += 24 * 60 #full day
      end

      minutes
    end
  end # AMPolicies
end # OMF::SFA::AM
