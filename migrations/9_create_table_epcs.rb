Sequel.migration do
  up do
    create_table(:epcs) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :control_ip_id, :ips, :on_delete => :set_null

      String :base_model
      String :vendor
      Integer :plmnid
    end
    alter_table(:e_node_bs) do
      add_foreign_key :epc_id, :epcs, :on_delete => :set_null
    end
  end

  down do
    drop_table(:epcs)
    drop_column(:e_node_bs, :epc_id)
  end
end