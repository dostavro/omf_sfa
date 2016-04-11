Sequel.migration do
  up do
    add_column :disk_images, :path, String
  end

  down do
    drop_column :disk_images, :path
  end
end

