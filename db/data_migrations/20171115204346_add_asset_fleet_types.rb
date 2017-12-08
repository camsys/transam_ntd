class AddAssetFleetTypes < ActiveRecord::DataMigration
  def up
    AssetFleetType.create!({groups: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacture_year,fuel_type_id', class_name: 'Vehicle', active: true}) if AssetFleetType.find_by(class_name: 'Vehicle').nil?
    AssetFleetType.create!({groups: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacture_year,fuel_type_id', class_name: 'SupportVehicle', active: true}) if AssetFleetType.find_by(class_name: 'SupportVehicle').nil?
  end

  def down
    AssetFleetType.where(name: 'Default').destroy!
  end
end