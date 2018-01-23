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


    # for each of the custom groups of the fleet type must do special selects and joins to pull out relevant info.
    asset_fleet_types.each do |fleet_type|

      group_by_fields = fleet_type.groups.split(',') + ['primary_modes.fta_mode_type_id as primary_fta_mode_type_id', 'IF(assets.pcnt_capital_responsibility > 0, "YES", "NO") as direct_capital_responsibility']

      query = fleet_type.class_name.constantize
                  .joins('LEFT JOIN (SELECT * FROM assets_fta_mode_types WHERE is_primary=1) AS primary_modes ON assets.id = primary_modes.asset_id')
                  .where(organization: organization)

      if fleet_type.class_name == 'Vehicle'

        group_by_fields << ['service_types.fta_service_type_id as primary_fta_service_type_id','secondary_modes.fta_mode_type_id as secondary_fta_mode_type_id', 'secondary_service_types.fta_service_type_id as secondary_fta_service_type_id']

        query = query
                    .joins('LEFT JOIN (SELECT * FROM assets_fta_service_types WHERE is_primary=1) AS service_types ON assets.id = service_types.asset_id')
                    .joins('LEFT JOIN (SELECT * FROM assets_fta_service_types WHERE is_primary IS NULL OR is_primary!=1) AS secondary_service_types ON assets.id = secondary_service_types.asset_id')
                    .joins('LEFT JOIN (SELECT * FROM assets_fta_mode_types WHERE is_primary IS NULL OR is_primary!=1) AS secondary_modes ON assets.id = -secondary_modes.asset_id')
      end

      group_by_values = query.joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id')
                            .where('assets_asset_fleets.asset_id IS NULL')
                            .group(*fleet_type.group_by_fields)
                            .pluck(*group_by_fields.flatten)

      group_by_values.each do |vals|

        conditions = []
        fleet_type.group_by_fields.each_with_index do |field, idx|
          if vals[idx].nil?
            conditions << "#{field} IS NULL"
          else
            conditions << "#{field} = ?"
          end
        end

        unless options[:action] == FleetBuilderProxy::USE_EXISTING_FLEET_ACTION
          fleet = AssetFleet.new
          fleet.organization_id = organization.id
          fleet.asset_fleet_type = fleet_type
          fleet.creator = sys_user
          fleet.save!
        else
          possible_assets = query
                                .having(conditions.join(' AND '), *(vals.reject! &:nil?))
                                .pluck(*group_by_fields.flatten, 'object_key').map{|x| x[-1]}
          fleet = AssetFleet.homogeneous.joins(:assets).where(assets: {object_key: possible_assets}).first
        end

        assets = Asset.where(object_key: query.joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id')
                                             .where('assets_asset_fleets.asset_id IS NULL')
                                             .having(conditions.join(' AND '), *(vals.reject! &:nil?))
                                             .pluck(*group_by_fields.flatten, 'object_key').map{|x| x[-1]}
        )
        fleet.assets << assets

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

