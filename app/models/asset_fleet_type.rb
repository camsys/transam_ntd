class AssetFleetType < ActiveRecord::Base
  # All types that are available
  scope :active, -> { where(:active => true) }

  def to_s
    class_name
  end

  def group_by_fields
    groups.split(',')
  end

end
