#------------------------------------------------------------------------------
# AssetGroup
#
# HBTM relationship with assets. Used as a generic bucket for grouping assets
# into loosely defined collections
#
#------------------------------------------------------------------------------
class AssetFleet < ActiveRecord::Base

  DECORATOR_METHOD_SIGNATURE = /^get_(.*)$/

  # Include the object key mixin
  include TransamObjectKey

  #------------------------------------------------------------------------------
  # Callbacks
  #------------------------------------------------------------------------------

  after_initialize  :set_defaults

  # Clear the mapping table when the group is destroyed
  before_destroy { assets.clear }

  #------------------------------------------------------------------------------
  # Associations
  #------------------------------------------------------------------------------

  # Every asset group is owned by an organization
  belongs_to :organization

  belongs_to :parent,    :class_name => "AssetFleet"

  belongs_to :asset_fleet_type

  belongs_to  :creator, :class_name => "User", :foreign_key => :created_by_user_id

  # Every asset grouop has zero or more assets
  has_and_belongs_to_many :assets, :inverse_of => :asset_fleet, :join_table => 'assets_asset_fleets'
  accepts_nested_attributes_for :assets, reject_if: :all_blank, allow_destroy: true

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
  validates :creator,                   :presence => true

  validates_inclusion_of :dedicated,  :in => [true, false]
  validates_inclusion_of :has_capital_responsibility,  :in => [true, false]
  validates_inclusion_of :active,  :in => [true, false]


  # List of hash parameters allowed by the controller
  FORM_PARAMS = [
      :object_key,
      :organization_id,
      :asset_fleet_type_id,
      :agency_fleet_id,
      :ntd_id,
      :dedicated,
      :has_capital_responsibility,
      :active,
      :assets_attributes => [:object_key, :asset_search_text, :_destroy]
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

  # Returns true if the asset group contains a homogeneous set of asset types, false otherwise
  def homogeneous?
    asset_types.length == 1
  end

  # Returns the unique set of asset_ids for assets stored in the group
  def asset_types
    AssetType.where(id: assets.scope.uniq.pluck(:asset_type_id))
  end

  def total_assets_count
    assets.count
  end

  def active_assets_count
    assets.operational.count
  end

  def group_by_fields
    a = []

    asset_fleet_type.group_by_fields.each do |field|
      if field[-3..-1] == '_id'
        field = field[0..-4]
      end

      label = field.humanize.titleize
      label = label.gsub('Fta', 'FTA')

      puts label
      a << [label, self.send('get_'+field)]
    end

    a
  end

  #-----------------------------------------------------------------------------
  # Recieves method requests. Anything that does not start with get_ is delegated
  # to the super model otherwise the request is tested against the model components
  # until a match is found or not in which case the call is delegated to the super
  # model to be evaluated
  #-----------------------------------------------------------------------------
  def method_missing(method_sym, *arguments)

    if method_sym.to_s =~ DECORATOR_METHOD_SIGNATURE
      # Strip off the decorator and see who can handle the real request
      actual_method_sym = method_sym.to_s[4..-1]
      if asset_fleet_type.groups.include? actual_method_sym
        typed_asset = Asset.get_typed_asset(assets.first)
        typed_asset.try(actual_method_sym)
      end
    else
      puts "Method #{method_sym.to_s} with #{arguments}"
      # Pass the call on -- probably generates a method not found exception
      super
    end
  end

  protected

  def set_defaults
    self.dedicated = self.dedicated.nil? ? true : false
    self.has_capital_responsibility = self.has_capital_responsibility.nil? ? true : false
    self.active = self.active.nil? ? true : false
  end

end
