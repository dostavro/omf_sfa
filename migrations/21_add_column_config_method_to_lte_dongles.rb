Sequel.migration do
  up do
    add_column :lte_dongles, :config_method, String
  end

  down do
    drop_column :lte_dongles, :config_method
  end
end
