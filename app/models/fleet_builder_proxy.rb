
class FleetBuilderProxy < Proxy

  # General state variables

  # organization
  attr_accessor     :organization_id

  # Type of asset type to process
  attr_accessor     :asset_fleet_types

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
