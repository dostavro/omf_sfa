Sequel.migration do
  up do
    create_table(:lte_dongles) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      Integer :category
      String  :lte_type
      String  :bands
      String  :imsi
      Integer :plmnid
    end
  end

  down do
    drop_table(:lte_dongles)
  end
end