#-------------------------------------------------------------------------------
#
# CapitalProjectBuilder
#
# Analyzes an organizations's assets and generates a set of capital projects
# for the organization.
#
#-------------------------------------------------------------------------------
class AssetFleetBuilder


  #-----------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #-----------------------------------------------------------------------------


  # Main entry point for the builder. This invokes the bottom-up builder
  def build(organization, options = {})

    sys_user = User.find_by(first_name: 'system')

    if options[:action] == FleetBuilderProxy::RESET_ALL_ACTION
      reset_all(organization)
    end

    asset_fleet_types = options[:asset_fleet_type_ids].blank? ? AssetFleetType.all : AssetFleetType.where(id: options[:asset_fleet_type_ids])

    asset_fleet_types.each do |fleet_type|

      query = fleet_type.class_name.constantize.joins(fleet_type.join_table_names.split(',').to_sym).joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id').where('assets_asset_fleets.asset_id IS NULL').where(organization: organization)
      group_by_fields = fleet_type.group_by_fields

      # custom always group by yes/no capital responsibility if Vehicle (pcnt capital responsibility is already grouped by SV)
      if fleet_type.class_name == 'Vehicle'
        group_by_fields << 'IF(assets.pcnt_capital_responsibility > 0, "YES", "NO")'
      end

      group_by_values = query.group(*group_by_fields).pluck(*group_by_fields)

      group_by_values.each do |vals|

        unless options[:action] == FleetBuilderProxy::USE_EXISTING_FLEET_ACTION
          fleet = AssetFleet.new
          fleet.organization_id = organization.id
          fleet.asset_fleet_type = fleet_type
          fleet.creator = sys_user
          fleet.save!
        else
          fleet = AssetFleet.homogeneous.joins(:assets).where(assets: {organization: organization}, asset_fleets: {created_by_user_id: sys_user.id}).where(Hash[*group_by_fields.map{|a| 'assets.'+a}.zip(vals).flatten]).first
        end

        fleet.assets << query.where(Hash[*group_by_fields.zip(vals).flatten])

      end

    end

  end

  def reset_all(organization)
    AssetFleet.where(organization: organization).destroy_all
  end

  # Set resonable defaults for the builder
  def initialize

  end

  #-----------------------------------------------------------------------------
  #
  # Private Methods
  #
  #-----------------------------------------------------------------------------
  private

end

