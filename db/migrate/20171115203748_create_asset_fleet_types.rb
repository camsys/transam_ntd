class CreateAssetFleetTypes < ActiveRecord::Migration
  def change
    create_table :asset_fleet_types do |t|
      t.string :name
      t.string :groups
      t.string :class_name
      t.boolean :active
    end
  end
end
