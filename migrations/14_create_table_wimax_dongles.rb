Sequel.migration do
  up do
    create_table(:wimax_dongles) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String  :bands
    end
  end

  down do
    drop_table(:wimax_dongles)
  end
end