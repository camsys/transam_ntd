class AddAssetFleetTypes < ActiveRecord::DataMigration
  def up
    AssetFleetType.create!({
           groups: 'asset_type_id,asset_subtype_id, fta_vehicle_type_id, dedicated,manufacturer_id,manufacture_year,fuel_type_id,dual_fuel_type_id,fta_ownership_type,fta_funding_type_id,fta_emergency_contingency_fleet,assets_fta_mode_types.fta_mode_type_id,assets_fta_service_types.fta_service_type_id',
           class_name: 'Vehicle',
           join_table_names: 'fta_mode_types,fta_service_types',
           active: true
     }) if AssetFleetType.find_by(class_name: 'Vehicle').nil?
    AssetFleetType.create!({groups: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacture_year,fuel_type_id,assets_fta_mode_types.fta_mode_type_id', class_name: 'SupportVehicle', active: true}) if AssetFleetType.find_by(class_name: 'SupportVehicle').nil?
  end

  def down
    AssetFleetType.delete_all
    AssetFleet.delete_all
    AssetsAssetFleet.delete_all
  end
end