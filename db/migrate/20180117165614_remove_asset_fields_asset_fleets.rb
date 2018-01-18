class RemoveAssetFieldsAssetFleets < ActiveRecord::Migration
  def change
    remove_column :dedicated, :asset_fleets
    remove_column :has_capital_responsibility, :asset_fleets
  end
end
