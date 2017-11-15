#------------------------------------------------------------------------------
# AssetGroup
#
# HBTM relationship with assets. Used as a generic bucket for grouping assets
# into loosely defined collections
#
#------------------------------------------------------------------------------
class AssetFleet < ActiveRecord::Base

  # Include the object key mixin
  include TransamObjectKey

  #------------------------------------------------------------------------------
  # Callbacks
  #------------------------------------------------------------------------------

  # Clear the mapping table when the group is destroyed
  before_destroy { assets.clear }

  #------------------------------------------------------------------------------
  # Associations
  #------------------------------------------------------------------------------

  # Every asset group is owned by an organization
  belongs_to :organization

  belongs_to :asset_fleet_type

  # Every asset grouop has zero or more assets
  has_and_belongs_to_many :assets

  #------------------------------------------------------------------------------
  # Scopes
  #------------------------------------------------------------------------------

  # All order types that are available
  scope :active, -> { where(:active => true) }

  #------------------------------------------------------------------------------
  # Validations
  #------------------------------------------------------------------------------
  validates :organization,              :presence => true
  validates :asset_fleet_type,          :presence => true

  validates_inclusion_of :dedicated,  :in => [true, false]
  validates_inclusion_of :has_capital_responsibility,  :in => [true, false]
  validates_inclusion_of :active,  :in => [true, false]

  # List of hash parameters allowed by the controller
  FORM_PARAMS = [
      :object_key,
      :organization_id,
      :ntd_id,
      :dedicated,
      :has_capital_responsibility,
      :active
  ]

  # List of fields which can be searched using a simple text-based search
  SEARCHABLE_FIELDS = [
  ]

  #------------------------------------------------------------------------------
  #
  # Class Methods
  #
  #------------------------------------------------------------------------------

  def self.allowable_params
    FORM_PARAMS
  end

  #------------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #------------------------------------------------------------------------------


  def to_s
    asset_fleet_type.to_s
  end

  def searchable_fields
    SEARCHABLE_FIELDS
  end

end
