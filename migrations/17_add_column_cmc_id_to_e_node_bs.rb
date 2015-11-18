Sequel.migration do
  up do
    alter_table(:e_node_bs) do
      add_foreign_key :cmc_id, :cmcs, :on_delete => :set_null
    end
  end

  down do
    alter_table(:e_node_bs) do
      drop_foreign_key :cmc_id
    end
  end
end
