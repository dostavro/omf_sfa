
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a user in the system.
  #
  class User < OResource
    has n, :project_memberships
    has n, :projects, :through => :project_memberships, :via => :project

    oproperty :keys, String, :functional => false

    def to_hash_long(h, objs, opts = {})
      super
      h[:projects] = self.projects.map do |p|
        p.to_hash_brief(opts)
      end
      h
    end

    def add_project(project)
      projects << project unless projects.include?(project)
      self.save
    end

    def get_all_accounts
      accounts = []

      self.projects.each do |proj|
        accounts <<  proj.account unless proj.account.nil?
      end
      accounts
    end

    def get_first_account
      ac = OMF::SFA::Resource::Account.first({name: self.name})
      return ac if ac && ac.project.users.first == self
      ac = self.projects.first.account
    end

    def has_nil_account?(am_manager)
      self.get_all_accounts.each do |acc|
        return true if acc == am_manager.get_scheduler.get_nil_account
      end
      false
    end

  end # User
end # module
