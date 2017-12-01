class AssetFleetsController < OrganizationAwareController

  add_breadcrumb "Home", :root_path
  add_breadcrumb "Asset Fleets", :asset_fleets_path

  before_action :set_asset_fleet, only: [:show, :edit, :update, :destroy]

  # GET /asset_fleets
  def index

    params[:sort] = 'organizations.short_name' if params[:sort] == 'organization'

    @asset_fleets = AssetFleet.where(organization_id: @organization_list).order("#{params[:sort]} #{params[:order]}").limit(params[:limit]).offset(params[:offset])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        fleets_json = @asset_fleets.collect{ |p|
          p.as_json.merge!({
            organization: p.organization.to_s,
            assets_count: p.assets.count
          })
        }
        render :json => {
            :total => @asset_fleets.count,
            :rows =>  fleets_json
        }
      }
      format.xls
    end
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
    @asset_fleet = AssetFleet.new(asset_fleet_params.except(:assets_attributes))

    @asset_fleet.assets = Asset.where(object_key: params[:asset_fleet][:assets_attributes].collect{|k, v| v[:object_key] unless v[:_destroy]=='true'})

    @asset_fleet.creator = current_user

    if @asset_fleet.save
      redirect_to @asset_fleet, notice: 'Asset fleet was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /asset_fleets/1
  def update


    if @asset_fleet.update(asset_fleet_params.except(:assets_attributes))
      @asset_fleet.assets = Asset.where(object_key: params[:asset_fleet][:assets_attributes].collect{|k, v| v[:object_key] unless v[:_destroy]=='true'})

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
    add_breadcrumb "Asset Fleet Builder"

    # Select the asset types that they are allowed to build. This is narrowed down to only
    # asset types they own
    @asset_types = []
    AssetType.all.each do |type|
      assets = Asset.where(asset_type: type)
      if assets.where(organization: @organization_list).count > 0
        @asset_types << {id: type.id, name: type.to_s, orgs: @organization_list.select{|o| assets.where(organization_id: o).count > 0}}
      end
    end

    @builder_proxy = FleetBuilderProxy.new

    @message = "Creating asset fleets. This process might take a while."
  end

  def runner
    add_breadcrumb "SOGR Capital Project Analyzer", builder_capital_projects_path
    add_breadcrumb "Running..."

    @builder_proxy = FleetBuilderProxy.new(params[:builder_proxy])
    if @builder_proxy.valid?

      if @builder_proxy.organization_id.blank?
        org_id = @organization_list.first
      else
        org_id = @builder_proxy.organization_id
      end
      org = Organization.get_typed_organization(Organization.find(org_id))

      Delayed::Job.enqueue CapitalProjectBuilderJob.new(org, @builder_proxy.asset_types, @builder_proxy.start_fy, current_user), :priority => 0

      # Let the user know the results
      msg = "SOGR Capital Project Analyzer is running. You will be notified when the process is complete."
      notify_user(:notice, msg)

      redirect_to capital_projects_url
      return
    else
      respond_to do |format|
        format.html { render :action => "builder" }
      end
    end
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
