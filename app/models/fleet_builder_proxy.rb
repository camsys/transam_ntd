
class FleetBuilderProxy < Proxy

  RESET_ALL_ACTION            = 0         # clear out all existing fleets and rebuilt
  USE_EXISTING_FLEET_ACTION   = 1         # add new assets to existing homogeneous fleets
  NEW_FLEETS_ACTION           = 2         # add new assets to new fleets

  # General state variables

  # organization
  attr_accessor     :organization_id

  # Type of asset type to process
  attr_accessor     :asset_fleet_types

  attr_accessor     :action

  # Basic validations. Just checking that the form is complete
  #validates :asset_fleet_types, :presence => true

  def initialize(attrs = {})
    super
    attrs.each do |k, v|
      self.send "#{k}=", v
    end
    self.asset_fleet_types ||= []
  end

end
