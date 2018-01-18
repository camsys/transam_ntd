class AddJoinTableNamesToAssetFleetTypes < ActiveRecord::Migration
  def change
    add_column :asset_fleet_types, :join_table_names, :string, after: :groups
  end
end
