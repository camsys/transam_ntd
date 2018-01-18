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
  scope :homogeneous, -> { where(:homogeneous => true) }

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
      :notes,
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
   "#{organization.short_name} #{asset_fleet_type} #{ntd_id}"
  end

  def searchable_fields
    SEARCHABLE_FIELDS
  end

  def ntd_id_label
    asset_klass = asset_fleet_type.try(:class_name)
    if asset_klass == 'Vehicle'
      'RVI ID'
    elsif asset_klass == 'SupportVehicle'
      'SV ID'
    elsif asset_klass.include? 'Facility'
      'Facility ID'
    end
  end

  def total_count
    assets.count
  end

  def active_count
    assets.in_service.count
  end

  def group_by_fields(labeled=true)
    a = Hash.new

    asset_fleet_type.group_by_fields.each do |field_name|
      if field_name[-3..-1] == '_id'
        field = field_name[0..-4]
      else
        field = field_name
      end

      if labeled
        label = field.humanize.titleize
        label = label.gsub('Fta', 'FTA')
      else
        label = field_name
      end

      a[label] = self.send('get_'+field)
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
        if self.homogeneous
          typed_asset = Asset.get_typed_asset(assets.first)
          typed_asset.try(actual_method_sym)
        else
          'ERROR: Assets do not match'
        end
      end
    else
      puts "Method #{method_sym.to_s} with #{arguments}"
      # Pass the call on -- probably generates a method not found exception
      super
    end
  end

  protected

  def set_defaults
    self.homogeneous = self.homogeneous.nil? ? true: self.homogeneous
    self.active = self.active.nil? ? true : self.active
  end

end
