
class FleetMappingProxy < Proxy

  # General state variables

  # organization
  attr_accessor     :asset_fleet_id

  # Type of asset type to process
  attr_accessor     :assets

  # Basic validations. Just checking that the form is complete
  validates :assets, :asset_fleet_id, :presence => true

  def initialize(attrs = {})
    super
    attrs.each do |k, v|
      self.send "#{k}=", v
    end
    self.assets ||= []
  end

end
