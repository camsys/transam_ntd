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



    AssetFleetType.all.each do |fleet_type|

      # voodoo to group by fields and return all assets with those values
      group_by_fields = fleet_type.group_by_fields
      group_by_values = fleet_type.class_name.constantize.where(organization: organization).group(group_by_fields).pluck(group_by_fields)

      group_by_values.each do |vals|

        if options[:use_existing]
          fleet = AssetFleet.joins(:assets).where(assets: {organization: organization}, asset_fleets: {parent_id: nil}).where(Hash[*group_by_fields.map{|a| 'assets.'+a}.zip(vals).flatten]).first
        else
          fleet = AssetFleet.new
          fleet.asset_fleet_type = fleet_type
          fleet.save!(:validate => false)
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


  def add_to_fleet(fleet, asset)
    # check that asset is not already in other fleets
    asset.asset_fleets.delete_all

    if get_possible_assets(fleet).include? asset
      asset.asset_fleets << fleet
    end
  end

  def remove_from_fleet(fleet, asset)
    if fleet.assets.include? asset
      fleet.assets.delete asset
    end
  end

  #-----------------------------------------------------------------------------
  # Creates a new capital project
  #-----------------------------------------------------------------------------
  def get_possible_fleets(asset, fleet_type)
    group_by_fields =fleet_type.group_by_fields

    AssetFleet.joins(:assets).where(Hash[*group_by_fields.map{|a| 'assets.'+a}.zip(asset.attributes.slice(*group_by_fields).values).flatten])
  end

  def get_possible_assets(fleet, no_current_fleets=false)
    group_by_fields = fleet.asset_fleet_type.group_by_fields
    group_by_values = fleet.assets.first.attributes.slice(*group_by_fields)

    assets = Asset.joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id').where(assets: group_by_values)

    if no_current_fleets
      assets = assets.where('assets_asset_fleets.asset_id IS NULL')
    end

    assets
  end

  #-----------------------------------------------------------------------------
  #
  # Private Methods
  #
  #-----------------------------------------------------------------------------
  private

end

