class CreateAssetFleets < ActiveRecord::Migration
  def change
    create_table :asset_fleets do |t|
      t.string :object_key, index: true
      t.references :organization, index: true
      t.references :asset_fleet_type
      t.integer :ntd_id
      t.boolean :dedicated
      t.boolean :has_capital_responsibility
      t.boolean :active

      t.timestamps
    end

    # create_join_table :asset_fleets, :assets do |t|
    #   t.index [:asset_fleet_id, :asset_id]
    #   t.index [:asset_id, :asset_fleet_id]
    # end
  end
end
