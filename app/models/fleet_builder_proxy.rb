
class FleetBuilderProxy < Proxy

  # General state variables

  # organization
  attr_accessor     :organization_id

  # Starting FY to generate projects for
  attr_accessor     :asset_fleet_type_id

  # Type of asset type to process
  attr_accessor     :asset_types

  # Basic validations. Just checking that the form is complete
  validates :asset_types, :asset_fleet_type_id, :presence => true

  def initialize(attrs = {})
    super
    attrs.each do |k, v|
      self.send "#{k}=", v
    end
    self.asset_types ||= []
  end

end
