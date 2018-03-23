#------------------------------------------------------------------------------
#
# CapitalProjectBuilderJob
#
# Build SOGR projects
#
#------------------------------------------------------------------------------
class AssetFleetBuilderJob < Job

  attr_accessor :organization
  attr_accessor :asset_fleet_types
  attr_accessor :builder_action
  attr_accessor :creator

  def run

    # Run the builder
    options = {}
    options[:action] = builder_action

    asset_fleet_types.each do |fleet_type_id|
      fleet_type = AssetFleetType.find_by(id: fleet_type_id)
      if fleet_type.present?
        builder = AssetFleetBuilder.new(fleet_type, organization)
        builder.build(options)

        msg = "Asset fleets built for #{organization.short_name}."
        # Add a row into the activity table
        ActivityLog.create({:organization_id => organization.id, :user_id => creator.id, :item_type => "AssetFleetBuilder", :activity => msg, :activity_time => Time.now})

        event_url = Rails.application.routes.url_helpers.asset_fleets_path
        builder_notification = Notification.create(text: msg, link: event_url, notifiable_type: 'Organization', notifiable_id: organization.id)
        UserNotification.create(user: creator, notification: builder_notification)
      end
    end
  end

  def prepare
    Rails.logger.debug "Executing AssetFleetBuilderJob at #{Time.now.to_s} for fleets"
  end

  def check
    raise ArgumentError, "organization can't be blank " if organization.nil?
    raise ArgumentError, "asset_fleet_types can't be blank " if asset_fleet_types.nil?
    raise ArgumentError, "creator can't be blank " if creator.nil?
  end

  def initialize(organization, asset_fleet_types, builder_action, creator)
    super
    self.organization = organization
    self.asset_fleet_types = asset_fleet_types
    self.builder_action = builder_action
    self.creator = creator
  end

end
