module TransamFleetable
  #------------------------------------------------------------------------------
  #
  #
  # Model
  #
  #------------------------------------------------------------------------------
  extend ActiveSupport::Concern

  included do

    # ----------------------------------------------------
    # Callbacks
    # ----------------------------------------------------

    before_save :check_fleet

    # ----------------------------------------------------
    # Associations
    # ----------------------------------------------------

    has_many :assets_asset_fleets, :foreign_key => :asset_id

    has_and_belongs_to_many :asset_fleets, :through => :assets_asset_fleets, :join_table => 'assets_asset_fleets', :foreign_key => :asset_id

    # ----------------------------------------------------
    # Validations
    # ----------------------------------------------------

  end

  #------------------------------------------------------------------------------
  #
  # Class Methods
  #
  #------------------------------------------------------------------------------

  module ClassMethods

  end

  #------------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #------------------------------------------------------------------------------

  def fiscal_year_mileage(fy_year=nil)
    fy_year = current_fiscal_year_year if fy_year.nil?

    last_date = start_of_fiscal_year(fy_year+1) - 1.day
    mileage_updates.where(event_date: last_date).last.try(:current_mileage)
  end

  protected

  def check_fleet

    asset_fleets.each do |fleet|
      #intersection
      self.changes.keys.each do |changed_field|
        if (fleet.asset_fleet_type.group_by_fields.include? changed_field)
          # asset technically should not belong to fleet anymore because its property(s) is different than the others so mark it as inactive
          AssetsAssetFleet.find_by(asset: self, asset_fleet: fleet).update(active: false)
        end
      end
    end

    return true
  end

end
