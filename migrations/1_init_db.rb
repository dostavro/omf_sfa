Sequel.migration do

  up do
    create_table :resources do
      primary_key :id
      foreign_key :account_id, :accounts, :on_delete => :set_null
      String :name
      String :urn
      String :uuid
      String :type
    end

    create_table(:components) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade 
      foreign_key :parent_id, :components, :on_delete => :cascade
      String :domain
      TrueClass :available
      String :status
      TrueClass :exclusive, :default => true
    end

    create_table(:nodes) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :sliver_type_id, :sliver_types, :on_delete => :set_null
      foreign_key :cmc_id, :on_delete => :set_null

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
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :node_id, :nodes, :on_delete => :cascade # If the node is deleted, delete also the interface
      foreign_key :link_id, :links, :on_delete => :set_null

      String :role
      String :mac
      String :description
    end

    create_table(:links) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String :link_type
    end

    create_table(:ips) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :interface_id, :interfaces, :on_delete => :cascade

      String :address
      String :netmask
      String :ip_type
    end

    create_table(:cmcs) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :ip_id, :ips, :on_delete => :set_null

      String :mac
    end

    create_table(:cpus) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :node_id, :nodes, :on_delete => :cascade

      String :cpu_type
      Integer :cores
      Integer :threads
      String :cache_l1
      String :cache_l2
    end

    create_table(:locations) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :node_id, :nodes, :on_delete => :cascade

      String :country
      String :city
      Integer :longitude
      Integer :latitude
    end

    create_table(:leases) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      DateTime :valid_from
      DateTime :valid_until
      String :status # pending, accepted, active, past, cancelled
    end

    create_table(:channels) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      String :frequency
    end

    create_table(:sliver_types) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :disk_image_id, :disk_images, :on_delete => :set_null
    end

    create_table(:disk_images) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String :os
      String :version
    end

    create_table(:components_leases) do
      foreign_key :component_id, :components, :on_delete => :cascade
      foreign_key :lease_id, :leases, :on_delete => :cascade
      primary_key [:component_id, :lease_id]
    end

    create_table(:accounts) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      DateTime :created_at
      DateTime :valid_until
      DateTime :closed_at
    end

    create_table(:users) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
    end

    create_table(:keys) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :user_id, :users, :on_delete => :cascade

      String :ssh_key
    end

    create_table(:accounts_users) do
      foreign_key :account_id, :accounts, :on_delete => :cascade
      foreign_key :user_id, :users, :on_delete => :cascade
      primary_key [:account_id, :user_id]
    end
  end

  down do
    drop_table(:accounts_users)
    drop_table(:keys)
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
    drop_table(:accounts)
    drop_table(:resources)
  end
end
