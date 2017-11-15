class AssetFleetsController < OrganizationAwareController

  add_breadcrumb "Home", :root_path
  add_breadcrumb "Asset Fleets", :asset_fleets_path

  before_action :set_asset_fleet, only: [:show, :edit, :update, :destroy]

  # GET /asset_fleets
  def index
    @asset_fleets = AssetFleet.where(organization_id: @organization_list)
  end

  # GET /asset_fleets/1
  def show
    add_breadcrumb @asset_fleet

  end

  # GET /asset_fleets/new
  def new
    add_breadcrumb 'New'

    @asset_fleet = AssetFleet.new
  end

  # GET /asset_fleets/1/edit
  def edit
    add_breadcrumb 'Update'

  end

  # POST /asset_fleets
  def create
    @asset_fleet = AssetFleet.new(asset_fleet_params)

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

    # Only allow a trusted parameter "white list" through.
    def asset_fleet_params
      params.require(:asset_fleet).permit(AssetFleet.allowable_params)
    end
end
