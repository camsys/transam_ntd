class CreateAssetFleetTypes < ActiveRecord::Migration
  def change
    create_table :asset_fleet_types do |t|
      t.string :name
      t.string :fields
      t.boolean :active
    end
  end
end
