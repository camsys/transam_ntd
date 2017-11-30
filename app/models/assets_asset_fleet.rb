class AssetsAssetFleet < ActiveRecord::Base

  belongs_to :asset
  belongs_to :asset_fleet

end
