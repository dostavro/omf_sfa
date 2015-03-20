Sequel.migration do
  up do
    create_table(:e_node_bs) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :control_ip_id, :ips, :on_delete => :set_null
      foreign_key :pgw_ip_id, :ips, :on_delete => :set_null
      foreign_key :mme_ip_id, :ips, :on_delete => :set_null
      foreign_key :epc_id, :epcs, :on_delete => :set_null

      String :base_model
      String :vendor
      String :band
      String :mode
      String :center_ul_frequency
      String :center_dl_frequency
      String :channel_bandwidth
      Integer :number_of_antennas
      String :tx_power
      Integer :mme_sctp_port
    end
  end

  down do
    drop_table(:e_node_bs)
  end
end