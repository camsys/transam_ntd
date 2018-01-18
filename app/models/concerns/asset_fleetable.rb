module AssetFleetable
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

    has_and_belongs_to_many :asset_fleets

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


  protected

  def check_fleet
    asset_fleets.each do |fleet|
      #intersection
      self.changes.keys.each do |changed_field|
        if (fleet.asset_fleet_type.group_by_fields.include? changed_field) &&
          # asset technically should not belong to fleet anymore because its property(s) is different than the others in fleet but for now mark fleet as non-homogeneous
          fleet.update_columns(homogeneous: fleet.assets.pluck(changed_field).uniq.count == 1)
        end
      end
    end
  end

end
