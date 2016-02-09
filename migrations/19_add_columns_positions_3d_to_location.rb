Sequel.migration do
  up do
    add_column :locations, :position_3d_x, Float
    add_column :locations, :position_3d_y, Float
    add_column :locations, :position_3d_z, Float
  end

  down do
    drop_column :locations, :position_3d_x
    drop_column :locations, :position_3d_y
    drop_column :locations, :position_3d_z
  end
end

