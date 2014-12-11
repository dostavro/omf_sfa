Sequel.migration do

  up do
    create_table :resources do
      primary_key :id
      foreign_key :account_id, :accounts
      String :name
      String :resource_type
      String :urn
      String :uuid
    end

    create_table(:components) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :parent_id, :components
      String :domain
      TrueClass :exclusive, :default => true
      TrueClass :available
      String :status
    end

    create_table(:nodes) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :sliver_type_id, :sliver_types
      foreign_key :cmc_id

      String :hardware_type
      String :hostname
      String :disk
      String :ram
      String :ram_type
      String :hd_capacity
      Integer :available_cpu # percentage of available cpu
      Integer :available_ram # percentage of available ram
      String :boot_state
    end

    create_table(:interfaces) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :node_id, :nodes
      foreign_key :link_id, :links

      String :role
      String :mac
      String :description
    end

    create_table(:links) do
      foreign_key :id, :resources, :primary_key => true

      String :link_type
    end

    create_table(:ips) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :interface_id, :interfaces

      String :address
      String :netmask
      String :ip_type
    end

    create_table(:cmcs) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :ip_id, :ips

      String :mac
    end

    create_table(:cpus) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :node_id, :nodes

      String :cpu_type
      Integer :cores
      Integer :threads
      String :cache_l1
      String :cache_l2
    end

    create_table(:locations) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :node_id, :nodes

      String :country
      String :city
      Integer :longitude
      Integer :latitude
    end

    create_table(:leases) do
      foreign_key :id, :resources, :primary_key => true
      DateTime :valid_from
      DateTime :valid_until
      String :status
    end

    create_table(:channels) do
      foreign_key :id, :resources, :primary_key => true
      String :frequency
    end

    create_table(:sliver_types) do
      foreign_key :id, :resources, :primary_key => true
      foreign_key :disk_image_id, :disk_images
    end

    create_table(:disk_images) do
      foreign_key :id, :resources, :primary_key => true

      String :os
      String :version
    end

    create_table(:components_leases) do
      foreign_key :component_id, :components
      foreign_key :lease_id, :leases
      primary_key [:component_id, :lease_id]
    end

    create_table(:accounts) do
      foreign_key :id, :resources, :primary_key => true

      DateTime :created_at # see if there is an automatic way of gettting this through the db
      DateTime :valid_until
      DateTime :closed_at
    end

    create_table(:users) do
      foreign_key :id, :resources, :primary_key => true

      String :keys # see if there is an array for keeping multiple ssh keys
    end

    create_table(:accounts_users) do
      foreign_key :account_id, :accounts
      foreign_key :user_id, :users
      primary_key [:account_id, :user_id]
    end
  end

  down do
    drop_table(:accounts_users)
    drop_table(:users)
    drop_table(:disk_images)
    drop_table(:sliver_types)
    drop_table(:channels)
    drop_table(:locations)
    drop_table(:cpus)
    drop_table(:cmcs)
    drop_table(:ips)
    drop_table(:links)
    drop_table(:interfaces)
    drop_table(:components_leases)
    drop_table(:leases)
    drop_table(:nodes)
    drop_table(:components)
    drop_column :resources, :account_id # need to do this first, otherwise complains about FOREIGN KEY constraint
    drop_table(:accounts)
    drop_table(:resources)
  end
end



