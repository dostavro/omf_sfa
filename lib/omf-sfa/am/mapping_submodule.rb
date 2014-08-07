# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.
require 'time'

DEFAULT_DURATION = 3600

class MappingSubmodule
  
  class UnknownTypeException < Exception; end

  # Initialize the mapping submodule
  #
  # @param [Hash] Options that come to the initialization of am_scheduler are also passed here.
  #  
  def initialize(opts = {})
    puts "MappingSubmodule INIT: opts #{opts}"
  end

  # Resolves an unbound query
  #
  # @param [Hash] the query
  # @param [OMF::SFA::AM::AMManager] the am_manager
  # @param [Authorizer] the authorizer 
  # @return [Hash] the resolved query
  # @raise [MappingSubmodule::UnknownTypeException] if no type is defined in the query
  #  
  def resolve(query, am_manager, authorizer)
    puts "MappingSubmodule: query: #{query}"

    query[:resources].each do |res|
      raise UnknownTypeException unless res[:type]
      resolve_valid_from(res) 
      resolve_valid_until(res)

      if res[:exclusive].nil? && query[:resources].first[:exclusive] #if exclusive is nil and at least one exclusive is given.
        resolve_exclusive(res, query[:resources], am_manager, authorizer)
      elsif res[:exclusive].nil?
        resolve_exclusive(res, am_manager, authorizer)
      end

      if res[:domain].nil? && query[:resources].first[:domain] #if domain is nil and at least one domain is given.
        resolve_domain(res, query[:resources], am_manager, authorizer)
      elsif res[:domain].nil?
        resolve_domain(res, am_manager, authorizer)
      end

      resolve_resource(res, query[:resources], am_manager, authorizer)
    end
    puts "Map resolve response: #{query}"
    query
  end

  private
    # Resolves the valid from for a specific resource in the query and adds it to the resource
    # that is passed as an arguement
    #
    # @param [Hash] the resource
    # @return [String] the resolved valid from
    # 
    def resolve_valid_from(resource)
      puts "resolve_valid_from: resource: #{resource}"
      return resource[:valid_from] = Time.parse(resource[:valid_from]).utc.to_s if resource[:valid_from]
      resource[:valid_from] = Time.now.utc.to_s 
    end

    # Resolves the valid until for a specific resource in the query and adds it to the resource
    # that is passed as an arguement
    #
    # @param [Hash] the resource
    # @return [String] the resolved valid until
    #
    def resolve_valid_until(resource)
      puts "resolve_valid_until: resource: #{resource}"
      return resource[:valid_until] = Time.parse(resource[:valid_until]).utc.to_s if resource[:valid_until]
      if duration = resource.delete(:duration)
        resource[:valid_until] = (Time.parse(resource[:valid_from]) + duration).utc.to_s
      else
        resource[:valid_until] = (Time.parse(resource[:valid_from]) + DEFAULT_DURATION).utc.to_s
      end
    end

    # Resolves the exclusive property for a specific resource in the query and adds it to the resource
    # that is passed as an arguement
    #
    # @param [Hash] the resource
    # @param [Hash] the resources of the query
    # @return [String] the resolved valid until
    #
    def resolve_exclusive(resource, resources = nil, am_manager, authorizer)
      puts "resolve_exclusive: resource: #{resource}, resources: #{resources.inspect}"
      return resource[:exclusive] = true unless resource[:type] == 'Node'
      unless resources.nil?
        resources.each do |res|
          if res[:exclusive] && resource[:type] == res[:type] # we might need to change res[:type] to res[:resource_type] in the future
            resource[:exclusive] = res[:exclusive]
            return resource[:exclusive]
          end
        end
      end
      all_resources = OMF::SFA::Resource::OResource.all({type: resource[:type]})
      all_excl_res = all_resources.select {|res| !res.exclusive.nil? && res.exclusive}

      av_resources = am_manager.find_all_available_resources({type: resource[:type]}, {}, resource[:valid_from], resource[:valid_until], authorizer)
      
      av_excl_res = av_resources.select {|res| res.exclusive}
      excl_percent = all_excl_res.size == 0 ? 0 : av_excl_res.size / all_excl_res.size

      av_non_excl_res = av_resources.select {|res| !res.exclusive.nil? && !res.exclusive}
      cpu_sum = 0
      ram_sum = 0
      av_non_excl_res.each do |res|
        cpu_sum += res.available_cpu
        ram_sum += res.available_ram
      end
      cpu_percent = av_non_excl_res.size == 0 ? 0 : cpu_sum / av_non_excl_res.size
      ram_percent = av_non_excl_res.size == 0 ? 0 : ram_sum / av_non_excl_res.size
      non_excl_percent = (cpu_percent + ram_percent) / 2

      resource[:exclusive] = excl_percent > non_excl_percent ? true : false
    end

    # Resolves the domain for a specific resource in the query and adds it to the resource
    # that is passed as an arguement
    #
    # @param [Hash] the resource
    # @param [Hash] the resources of the query
    # @return [String] the resolved domain
    # @raise [OMF::SFA::AM::UnknownResourceException] if no available resources match the query
    #
    def resolve_domain(resource, resources = nil, am_manager, authorizer)
      puts "resolve_domain: resource: #{resource}, resources: #{resources.inspect}"
      unless resources.nil?
        resources.each do |res|
          if res[:domain] && resource[:type] == res[:type] && resource[:exclusive] == res[:exclusive] # we might need to change/add res[:type] to res[:resource_type] in the future
            resource[:domain] = res[:domain]
            return resource[:domain]
          end
        end
      end

      domains = {}
      resources = am_manager.find_all_available_resources({type: resource[:type]}, {exclusive: resource[:exclusive]}, resource[:valid_from], resource[:valid_until], authorizer)

      # resources = resources.select { |res| res[:exclusive] == resource[:exclusive] } if resource[:exclusive]

      resources.each do |res|
        if res.domain
          if domains.has_key?(res.domain)
            domains[res.domain] += 1 
          else
            domains[res.domain] = 0
          end
        end
      end

      raise OMF::SFA::AM::UnavailableResourceException if domains.empty?

      resource[:domain] = domains.max_by{|k,v| v}.first
    end

    # Resolves to an existing resource for a specific resource in the query and adds the urn and the uuid 
    # to the resource that is passed as an arguement
    #
    # @param [Hash] the resource
    # @param [Hash] all the resources of the query
    # @param [OMF::SFA::AM::AMManager] the am_manager
    # @param [Authorizer] the authorizer 
    # @return [String] the resolved urn
    # @raise [OMF::SFA::AM::UnknownResourceException] if no available resources match the query
    #
    def resolve_resource(resource, resources, am_manager, authorizer)
      puts "resolve_resource: resource: #{resource}, resources: #{resources}"
      descr = {}
      descr[:type] = resource[:type]
      oprops_descr = {}
      oprops_descr[:domain] = resource[:domain]
      oprops_descr[:exclusive] = resource[:exclusive]
      av_resources = am_manager.find_all_available_resources(descr, oprops_descr, resource[:valid_from], resource[:valid_until], authorizer)
      
      resources.each do |res| #remove already given resources
        av_resources.each do |ares|
          av_resources.delete(ares) if res[:uuid] && ares.uuid.to_s == res[:uuid]
        end
      end
      raise OMF::SFA::AM::UnavailableResourceException if av_resources.empty?

      res = av_resources.sample
      resource[:uuid] = res.uuid.to_s
      resource[:urn] = res.urn
      resource[:urn]
    end
end