class AssetFleetsController < OrganizationAwareController

  layout 'asset_fleets'

  add_breadcrumb "Home", :root_path
  add_breadcrumb "Fleets", :asset_fleets_path

  before_action :set_asset_fleet, only: [:show, :edit, :update, :destroy, :remove_asset]

  # GET /asset_fleets
  def index
    params[:sort] ||= 'ntd_id'

    params[:sort] = 'organizations.short_name' if params[:sort] == 'organization'

    @fta_asset_category = (FtaAssetCategory.find_by(id: params[:fta_asset_category_id]) || FtaAssetCategory.first)
    @asset_fleet_types = AssetFleetType.where(class_name: @fta_asset_category.asset_types.pluck(:class_name))

    @asset_fleets = AssetFleet.where(organization_id: @organization_list, asset_fleet_type_id: @asset_fleet_types.pluck(:id))

    add_breadcrumb @fta_asset_category.name == 'Equipment' ? "Support Vehicles" : @fta_asset_category.to_s
    @message = "Creating asset fleets. This process might take a while."

    respond_to do |format|
      format.html 
      format.json {
        render :json => {
            :total => @asset_fleets.count,
            :rows =>  @asset_fleets.order("#{params[:sort]} #{params[:order]}").limit(params[:limit]).offset(params[:offset])
        }
      }
      format.xls
    end
  end

  def orphaned_assets
    # check that an order param was provided otherwise use asset_tag as the default
    params[:sort] ||= 'asset_tag'

    orphaned_assets = Asset
                          .joins('LEFT JOIN assets_asset_fleets ON assets.id = assets_asset_fleets.asset_id')
                          .where(asset_type: AssetType.where(class_name: ['Vehicle', 'SupportVehicle']), organization_id: @organization_list)
                          .where('assets_asset_fleets.asset_id IS NULL')

    respond_to do |format|
      format.html
      format.json {

        # merge fields that
        orphaned_assets_json = orphaned_assets.order("#{params[:sort]} #{params[:order]}").limit(params[:limit]).offset(params[:offset]).collect{ |p|
          p.as_json.merge!({
             serial_number: p.serial_number,
             license_plane: p.license_plate,
             manufacturer_model: p.manufacturer_model,
             vehicle_type: (FtaVehicleType.find_by(id: p.fta_vehicle_type_id) || FtaSupportVehicleType.find_by(id: p.fta_support_vehicle_type_id)).to_s,
             action: new_asset_asset_fleets_path(asset_object_key: p.object_key)
         })
        }

        render :json => {
            :total => orphaned_assets.count,
            :rows =>  orphaned_assets_json
        }
      }
      format.xls
    end
  end

  # GET /asset_fleets/1
  def show
    add_breadcrumb @asset_fleet

    builder = AssetFleetBuilder.new(@asset_fleet.asset_fleet_type, @asset_fleet.organization)
    @available_assets = builder.available_assets(builder.asset_group_values({fleet: @asset_fleet}))

  end

  # GET /asset_fleets/new
  def new
    add_breadcrumb 'New'

    @asset_fleet = AssetFleet.new
  end

  # GET /asset_fleets/1/edit
  def edit
    add_breadcrumb @asset_fleet, asset_fleet_path(@asset_fleet)
    add_breadcrumb 'Update'

  end

  # POST /asset_fleets
  def create
    @asset_fleet = AssetFleet.new(asset_fleet_params.except(:assets_attributes))

    @asset_fleet.assets = Asset.where(object_key: params[:asset_object_key])

    @asset_fleet.creator = current_user

    if @asset_fleet.save
      redirect_to @asset_fleet, notice: 'Asset fleet was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /asset_fleets/1
  def update
    if @asset_fleet.update(asset_fleet_params)
      redirect_to @asset_fleet, notice: 'Asset fleet was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /asset_fleets/1
  def destroy
    @asset_fleet.destroy
    redirect_to asset_fleets_url, notice: 'Asset fleet was successfully destroyed.'
  end

  def builder
    add_breadcrumb "Manage Fleets"

    # Select the asset types that they are allowed to build. This is narrowed down to only
    # asset types they own
    @asset_types = AssetType.where(id: Asset.where(organization: @organization_list).pluck('DISTINCT asset_type_id'))
    puts @asset_types.inspect

    @builder_proxy = FleetBuilderProxy.new

    @message = "Creating asset fleets. This process might take a while."
  end

  def runner

    @builder_proxy = FleetBuilderProxy.new(params[:fleet_builder_proxy])
    if @builder_proxy.valid?

      if @builder_proxy.organization_id.blank?
        org_id = @organization_list.first
      else
        org_id = @builder_proxy.organization_id
      end
      org = Organization.get_typed_organization(Organization.find(org_id))

      Delayed::Job.enqueue AssetFleetBuilderJob.new(org, @builder_proxy.asset_fleet_types, @builder_proxy.action,current_user), :priority => 0

      # Let the user know the results
      msg = "Fleet Builder is running. You will be notified when the process is complete."
      notify_user(:notice, msg)

      redirect_to asset_fleets_path
      return
    else
      respond_to do |format|
        format.html { render :action => "builder" }
      end
    end
  end

  def new_asset
    asset = Asset.find_by(object_key: params[:asset_object_key])

    unless asset.nil?
      @asset = Asset.get_typed_asset(asset)

      # potential new fleet
      @asset_fleet = AssetFleet.new(organization_id: @asset.organization_id, asset_fleet_type: AssetFleetType.find_by(class_name: @asset.asset_type.class_name))
      @asset_fleet.assets << @asset

      builder = AssetFleetBuilder.new(AssetFleetType.find_by(class_name: @asset.asset_type.class_name), @asset.organization)
      @available_fleets = builder.available_fleets(builder.asset_group_values({asset: @asset}))
    else
      redirect_to builder_asset_fleets_path
    end
  end

  def add_asset

    @asset_fleet = AssetFleet.find_by(id: params[:fleet_asset_builder][:asset_fleet_id])
    @asset = Asset.find_by(id: params[:fleet_asset_builder][:asset_id])

    @asset_fleet.assets << @asset

    redirect_to :back
  end

  def remove_asset
    @asset = Asset.find_by(object_key: params[:asset])

    if @asset.present?
      @asset_fleet.assets.delete @asset
    end

    redirect_to :back
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_asset_fleet
      @asset_fleet = AssetFleet.find_by(object_key: params[:id], organization_id: @organization_list)

      if @asset_fleet.nil?
        if AssetFleet.find_by(object_key: params[:id]).nil?
          redirect_to '/404'
        else
          notify_user(:warning, 'This record is outside your filter. Change your filter if you want to access it.')
          redirect_to asset_fleets_path
        end
        return
      end

    end

  def fleet_asset_builder_params
    params.require(:fleet_asset_builder_proxy).permit(FleetAssetBuilderProxy.allowable_params)
  end

    # Only allow a trusted parameter "white list" through.
    def asset_fleet_params
      params.require(:asset_fleet).permit(AssetFleet.allowable_params)
    end
end
