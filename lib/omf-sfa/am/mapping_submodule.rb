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
      resolve_domain(res) unless res[:domain]
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
      # valid_from = res[:valid_from]
      # valid_until = res[:valid_until]

      puts "Map: find_all_available_resources: res: #{res.inspect} from: #{res[:valid_from]} until: #{res[:valid_until]}"
      resources = am_manager.find_all_available_resources({type: res[:type]}, {domain: res[:domain]}, res[:valid_from], res[:valid_until], authorizer)
      resolve_uuid(res, resources)
    end
    puts "Response: #{msg}"
    msg
  end

  private
    #TODO add some clever mechanic to take the type of node into account
    #des poios exei ta perissotera free kai epelekse auton
    def resolve_domain(resource)
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

    def resolve_uuid(resource, resources)
      puts "resolve_uuid: resource: #{resource}, resources: #{resources}"
      resource[:uuid] = resources.sample.uuid.to_s
      puts "uuid: #{resource[:uuid]}"
      resource
    end
end