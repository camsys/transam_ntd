class AddParentAssetFleets < ActiveRecord::Migration
  def change
    add_column :asset_fleets, :parent_id, :integer, after: :ntd_id

  end
end
