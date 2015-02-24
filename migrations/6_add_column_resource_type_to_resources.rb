Sequel.migration do
  up do
    add_column :resources, :resource_type, String
  end

  down do
    drop_column :resources, :resource_type
  end
end
