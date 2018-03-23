class AssetFleetsController < OrganizationAwareController

  layout 'asset_fleets'

  add_breadcrumb "Home", :root_path
  add_breadcrumb "Asset Fleets", :asset_fleets_path

  before_action :set_asset_fleet, only: [:show, :edit, :update, :destroy, :remove_asset]

  # GET /asset_fleets
  def index
    params[:sort] ||= 'ntd_id'

    params[:sort] = 'organizations.short_name' if params[:sort] == 'organization'

    @fta_asset_category = (FtaAssetCategory.find_by(id: params[:fta_asset_category_id]) || FtaAssetCategory.first)
    @asset_fleet_types = AssetFleetType.where(class_name: @fta_asset_category.asset_types.pluck(:class_name))

    @asset_fleets = AssetFleet.where(organization_id: @organization_list, asset_fleet_type_id: @asset_fleet_types.pluck(:id)).order("#{params[:sort]} #{params[:order]}").limit(params[:limit]).offset(params[:offset])

    @message = "Creating asset fleets. This process might take a while."

    respond_to do |format|
      format.html 
      format.json {
        render :json => {
            :total => @asset_fleets.count,
            :rows =>  @asset_fleets
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

    # Select the fta asset categories that they are allowed to build.
    # This is narrowed down to only asset types they own
    @fta_asset_categories = []
    rev_vehicles = FtaAssetCategory.find_by(name: 'Revenue Vehicles')
    @fta_asset_categories << {id: rev_vehicles.id, label: rev_vehicles.to_s} if Asset.where(organization_id: @organization_list, asset_type: rev_vehicles.asset_types).count > 0
    @fta_asset_categories << {id: FtaAssetCategory.find_by(name: 'Equipment').id, label: 'Support Vehicles'} if SupportVehicle.where(organization_id: @organization_list).count > 0

    @message = "Creating asset fleets. This process might take a while."
  end

  def runner

    fta_asset_category = FtaAssetCategory.find_by(id: params[:fta_asset_category_id])

    if fta_asset_category.present?
      Delayed::Job.enqueue AssetFleetBuilderJob.new(TransitOperator.where(id: @organization_list), AssetFleetType.where(class_name: fta_asset_category.asset_types.pluck(:class_name)), FleetBuilderProxy::RESET_ALL_ACTION,current_user), :priority => 0

      # Let the user know the results
      msg = "Fleet Builder is running. You will be notified when the process is complete."
      notify_user(:notice, msg)
    end

    redirect_to :back
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
