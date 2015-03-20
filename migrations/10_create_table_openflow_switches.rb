Sequel.migration do
  up do
    create_table(:openflow_switches) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :of_controller_ip_id, :ips, :on_delete => :set_null

      String :hostname
      String :switch_model
      String :openflow_version
      String :switch_os
      String :datapathid
      Integer :of_controller_port
    end

    alter_table(:interfaces) do
      add_foreign_key :openflow_switch_id, :openflow_switches, :on_delete => :cascade
    end
  end

  down do
    drop_table(:openflow_switches)
    drop_column :interfaces, :openflow_switch_id
  end
end