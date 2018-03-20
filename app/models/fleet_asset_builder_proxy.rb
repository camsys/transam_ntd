
class FleetAssetBuilderProxy < Proxy

  # General state variables

  # organization
  attr_accessor     :asset

  # Type of asset type to process
  attr_accessor     :asset_fleet_id

  # Basic validations. Just checking that the form is complete
  #validates :asset_fleet_types, :presence => true

  def initialize(attrs = {})
    super
    attrs.each do |k, v|
      self.send "#{k}=", v
    end
  end

end
