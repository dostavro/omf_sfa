# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.
require 'time'

DEFAULT_DURATION = 3600

class MappingSubmodule
  
  class UnknownTypeException < Exception; end

  def initialize(opts = {})
    puts "MappingSubmodule INIT: opts #{opts}"
  end

  def resolve(msg, am_manager, authorizer)
    puts "MappingSubmodule: msg: #{msg}"

    msg[:resources].each do |res|
      raise UnknownTypeException unless res[:type]
      if res[:domain].nil? && msg[:resources].first[:domain] #if domain is nil and at least one domain is given.
        resolve_domain(res, msg[:resources])
      elsif res[:domain].nil?
        resolve_domain(res)
      end
      unless res[:valid_from]
        resolve_valid_from(res) 
      else
        res[:valid_from] = Time.parse(res[:valid_from]).utc.to_s
      end
      unless res[:valid_until]
        resolve_valid_until(res)
      else
        res[:valid_until] = Time.parse(res[:valid_until]).utc.to_s
      end

      resolve_uuid(res, msg[:resources], am_manager, authorizer)
    end
    puts "Map resolve response: #{msg}"
    msg
  end

  private
    #TODO add some clever mechanic to take the type of node into account in order to specify the type of testbed (wireless, vm, etc)
    def resolve_domain(resource, resources = nil)
      puts "resolve_domain: resource: #{resource}, resources: #{resources.inspect}"
      unless resources.nil?
        resources.each do |res|
          if res[:domain] && resource[:type] == res[:type] # we might need to change res[:type] to res[:resource_type] in the future
            resource[:domain] = res[:domain]
            return resource[:domain]
          end
        end
      end

      domains = {}
      resources = OMF::SFA::Resource::OResource.all({type: resource[:type]})
      resources.each do |res|
        if res.domain
          if domains.has_key?(res.domain)
            domains[res.domain] += 1 
          else
            domains[res.domain] = 0
          end
        end
      end

      resource[:domain] = domains.max_by{|k,v| v}.first
    end

    def resolve_valid_from(resource)
      resource[:valid_from] = Time.now.utc.to_s 
    end

    def resolve_valid_until(resource)
      if duration = resource.delete(:duration)
        resource[:valid_until] = (Time.parse(resource[:valid_from]) + duration).utc.to_s
      else
        resource[:valid_until] = (Time.parse(resource[:valid_from]) + DEFAULT_DURATION).utc.to_s
      end
    end

    def resolve_uuid(resource, resources, am_manager, authorizer)
      puts "resolve_uuid: resource: #{resource}, resources: #{resources}"
      av_resources = am_manager.find_all_available_resources({type: resource[:type]}, {domain: resource[:domain]}, resource[:valid_from], resource[:valid_until], authorizer)
      resources.each do |res| #remove already given resources
        av_resources.each do |ares|
          av_resources.delete(ares) if res[:uuid] && ares.uuid.to_s == res[:uuid]
        end
      end

      resource[:uuid] = av_resources.sample.uuid.to_s
      puts "uuid: #{resource[:uuid]}"
      resource[:uuid]
    end
end