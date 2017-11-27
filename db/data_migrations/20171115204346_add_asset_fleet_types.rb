class AddAssetFleetTypes < ActiveRecord::DataMigration
  def up
    AssetFleetType.create!({name: 'Default', groups: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacturer_model,manufacture_year,fuel_type_id', class_name: 'Vehicle', active: true})
    AssetFleetType.create!({name: 'Default', groups: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacturer_model,manufacture_year,fuel_type_id, fta_funding_type_id', class_name: 'SupportVehicle', active: true})
  end

  def down
    AssetFleetType.where(name: 'Default').destroy!
  end
end