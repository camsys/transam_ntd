class AddAssetFleetTypes < ActiveRecord::DataMigration
  def up
    AssetFleetType.create!({name: 'Default', fields: 'asset_type_id,asset_subtype_id,manufacturer_id,manufacturer_model,manufacture_year,fuel_type_id', active: true})
  end

  def down
    AssetFleetType.find_by(name: 'Default').destroy!
  end
end