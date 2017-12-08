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

    reset_all(organization)

    sys_user = User.find_by(first_name: 'system')

    asset_fleet_types = options[:asset_fleet_type_ids].blank? ? AssetFleetType.all : AssetFleetType.find_by(id: options[:asset_fleet_type_ids])

    asset_fleet_types.each do |fleet_type|

      # voodoo to group by fields and return all assets with those values
      group_by_fields = fleet_type.group_by_fields
      group_by_values = fleet_type.class_name.constantize.where(organization: organization).group(*group_by_fields).pluck(*group_by_fields)

      group_by_values.each do |vals|

        if options[:use_existing]
          fleet = AssetFleet.joins(:assets).where(assets: {organization: organization}, asset_fleets: {created_by_user_id: sys_user.id}).where(Hash[*group_by_fields.map{|a| 'assets.'+a}.zip(vals).flatten]).first
        else
          fleet = AssetFleet.new
          fleet.organization_id = organization.id
          fleet.asset_fleet_type = fleet_type
          fleet.creator = sys_user
          fleet.save!
        end

        fleet.assets = Asset.joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id').where('assets_asset_fleets.asset_id IS NULL').where(Hash[*group_by_fields.map{|a| 'assets.'+a}.zip(vals).flatten])

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

