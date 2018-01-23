#-------------------------------------------------------------------------------
#
# CapitalProjectBuilder
#
# Analyzes an organizations's assets and generates a set of capital projects
# for the organization.
#
#-------------------------------------------------------------------------------
class AssetFleetBuilder


  #-----------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #-----------------------------------------------------------------------------


  # Main entry point for the builder. This invokes the bottom-up builder
  def build(organization, options = {})

    AssetFleet.where(organization: organization).destroy_all

    AssetFleetType.all.each do |fleet_type|

      # voodoo to group by fields and return all assets with those values
      group_by_fields = fleet_type.group_by_fields
      group_by_values = fleet_type.class_name.constantize.where(organization: organization).group(group_by_fields).pluck(group_by_fields)
      assets = Asset.where(organization: organization).where(Hash[*group_by_fields.zip(group_by_values).flatten])

      fleet = AssetFleet.new
      fleet.asset_fleet_type = fleet_type
      fleet.assets = assets
      fleet.save!(:validate => false)


    end
  end

  def update_asset_schedule(asset)

    # Make sure the asset is strongly typed
    a = asset.is_typed? ? asset : Asset.get_typed_asset(asset)

    # Run the update
    unless a.replacement_pinned?
      process_asset(a, @start_year, @last_year, @replacement_project_type, @rehabilitation_project_type)
    end

    # Cleanup any empty projects and AL Is
    {:deleted_alis => post_build_clean_up(asset.organization)}

  end

  #-----------------------------------------------------------------------------
  # Update an activity line item and all of its assets to a new planning year
  # Note what process_asset actually does is create a new ALI
  #-----------------------------------------------------------------------------
  def move_ali_to_planning_year(ali, fy_year, early_replacement_reason)
    unless ali.present?
      Rails.logger.warning "Missing ALI"
      return nil
    end
    unless fy_year.present?
      Rails.logger.warning "Missing fy_year"
      return nil
    end

    # Double check that we are not copying to the same year
    if ali.fy_year == fy_year
      Rails.logger.info "Can't move ALI to the same year. Nothing to do."
      return nil
    end
    # Double check that we are not attempting to move a notional project
    if ali.notional?
      Rails.logger.info "Can't move ALIs that correspond to notional planned projects."
      return nil
    end

    # Get the capital project.
    project = ali.capital_project
    # We need to know what type of project we are working with and go through all
    # the cases
    if project.multi_year?
      # Multi year projects do not have assets associated with them for now. The
      # ALI can be simply moved to the selected year.
      Rails.logger.debug "Multi-year project. Moving ALI to #{fy_year}"
      ali.fy_year = fy_year
      if ali.fy_year < project.fy_year
        Rails.logger.debug "Multi-year project. Moving project to #{fy_year}"
        project.fy_year = ali.fy_year
      end
      ali.save(:validate => false)
      # Update the starting fiscal year if needed
      project.update_project_fiscal_year
      if project.changed?
        # If the FY changes we need to update the project number
        project.update_project_number
        project.save(:validate => false)
      end
      projects_and_alis = [[project, ali]]
    elsif project.capital_project_type_id == REPLACEMENT_PROJECT_TYPE or project.capital_project_type_id == IMPROVEMENT_PROJECT_TYPE
      Rails.logger.debug "Replacement or Rehabilitation project"
      # These are replacement or improvement projects and may have assets
      # associated with them. If they are SOGR projects we are allowed to manage
      # the projects and ALIs otherwise we must leave empty projects and ALIs
      # for the user to clean up
      Rails.logger.debug "ALI has #{ali.assets.count} assets"
      if ali.assets.present?
        # Need to figure out if it is a SOGR project or not. SOGR projects are
        # internally managed while non-SOGR projects are not.
        # Take each asset, update the scheduled activity year and re-run it
        projects_and_alis = []
        ali.assets.each do |x|
          asset = Asset.get_typed_asset(x)
          Rails.logger.debug "Processing #{asset}"
          if project.capital_project_type_id == REPLACEMENT_PROJECT_TYPE
            # Set the scheduled replacement year
            asset.scheduled_replacement_year = fy_year
            # Update early_replacement_reason if applicable
            asset.update_early_replacement_reason early_replacement_reason
          else
            asset.scheduled_rehabilitation_year = fy_year
          end
          asset.save(:validate => false)
          projects_and_alis += process_asset(asset, @start_year, @last_year, @replacement_project_type, @rehabilitation_project_type)
        end
        ali.reload
        project.reload
      else
        # There are no assets so we can move the ALI. First we need to see
        # if an existing project exists in the target year. If not we create
        # it by copying the existing one
        new_project = CapitalProject.find_by('organization_id = ? AND team_ali_code_id = ? AND fy_year = ? AND sogr = ? and notional = ?', project.organization.id, project.team_ali_code.id, fy_year, project.sogr, project.notional)
        if new_project.nil?
          # Not found so copy the existing project to the new year
          Rails.logger.debug "Project not found. Duplicating existing project"
          new_project = project.dup
          new_project.object_key = nil
          new_project.fy_year = fy_year
          new_project.save
        else
          Rails.logger.debug "Existing project found #{new_project}."
        end
        ali.capital_project = new_project
        ali.fy_year = fy_year
        ali.save
        ali.reload
        new_project.reload
        project.reload
        projects_and_alis = [[new_project, ali]]
      end

    elsif project.capital_project_type_id == EXPANSION_PROJECT_TYPE
      # Its an expansion project -- these dont have assets so we can simply move
      # the ALI to the new fy year and make sure that a project exists for it

      # Use the utility method to set up a new project and ALI if needed. This
      # retuns an array [project, ali]
      a = add_to_project(project.organization, il, ali.team_ali_code, fy_year, project.capital_project_type, project.sogr, project.notional)
      new_project = a.first
      new_ali = a.last
      # We don't need the new ali so we can just replace the new one on the
      # project with the old one after updating the fy_year. This preserves
      # any documents, comments, etc. that are asscoiated with this ALI
      new_project.activity_line_items.destroy new_ali
      ali.capital_project = new_project
      ali.fy_year = fy_year
      ali.save(:validate => false)
      ali.reload
      # complete the update and we are done
      new_project.activity_line_items << ali
      new_project.save(:validate => false)
      new_project.reload
      projects_and_alis = [[new_project, ali]]
    end

    # Cleanup any empty projects and ALIs
    {:deleted_alis => post_build_clean_up(project.organization), :touched_alis => projects_and_alis}


  end

  # Set resonable defaults for the builder
  def initialize
    # These are hashes for caching scopes so we don't have to look them up all the time
    @replace_subtype_scope_cache = {}
    @rehab_subtype_scope_cache = {}

    # Keep track of how many projects were created
    @project_count = 0

    # Get the current fiscal year and the last year that we will generate projects for. We can only generate projects for planning years
    # Year 1, Year 2,..., Year 12
    @start_year = current_planning_year_year
    @last_year = last_fiscal_year_year

    @replacement_project_type = CapitalProjectType.find_by_code('R')
    @rehabilitation_project_type = CapitalProjectType.find_by_code('I')

  end

  #-----------------------------------------------------------------------------
  # Protected Methods
  #-----------------------------------------------------------------------------
  protected

  def post_build_clean_up organization
    # destroy all empty ALIs
    deleted_alis =  ActivityLineItem.joins('LEFT OUTER JOIN activity_line_items_assets ON activity_line_items.id = activity_line_items_assets.activity_line_item_id').where('activity_line_items_assets.activity_line_item_id IS NULL').joins(:capital_project).where('capital_projects.sogr = true')
    deleted_projs_alis = deleted_alis.map{|x| [x.capital_project, x]}

    deleted_alis.destroy_all

    # update cost of all other ALIs
    ActivityLineItem.joins(:assets).where("assets.organization_id = ?",organization.id).group("activity_line_items.id").each{ |ali| ali.update_estimated_cost}

    # destroy all empty capital projects
    CapitalProject.where(:organization_id => organization.id, :sogr => true).joins('LEFT OUTER JOIN activity_line_items ON capital_projects.id = activity_line_items.capital_project_id').where('activity_line_items.capital_project_id IS NULL').destroy_all

    deleted_projs_alis
  end

  def build_bottom_up(organization, options)

    Rails.logger.debug "options = #{options.inspect}"

    # Get the options. There must be at least one type of asset to process
    asset_type_ids = options[:asset_type_ids].blank? ? organization.asset_type_counts.keys : options[:asset_type_ids]
    # User must set the start fy year as well otherwise we use the first planning year
    if options[:start_fy].to_i > 0
      @start_year = options[:start_fy].to_i
    end

    #---------------------------------------------------------------------------
    # Basic Algorithm:
    #
    # For each selected asset type...
    #   For each asset that is not disposed or marked for disposition...
    #
    #     Step 1: Make sure that it has a scheduled replacement year and in_seervice_date.
    #             Update the asset if these are not set
    #     Step 2: if the scheduled replacement year is before the first planning year or after the last
    #             planning year there is nothing to do so skip to Step 5
    #     Step 3: Check to see if a replacement project exists and create it if it does not. Add
    #             the asset to the replacement project
    #     Step 4: Get the policy and see if the replacement can be replaced within the planning time frame
    #             Add new projects for each replacement cycle
    #     Step 5: Check to see if the asset has a rehabilitation year set. If so create a rehabilitation
    #             project if one does not exist or add to it if it does exist.
    #
    #---------------------------------------------------------------------------

    # Get the current fiscal year and the last year that we will generate projects for. We can only generate projects
    # for planning years Year 1, Year 2,..., Year 12
    # @start_year = current fiscal year
    # @last_year = last year that we will generate projects for

    Rails.logger.info  "start_year = #{@start_year}, last_year  #{@last_year}"

    # Loop through the list of asset type ids
    policy = Policy.find_by(organization_id: organization.id)
    policy_type_rules = Hash[*PolicyAssetTypeRule.where(policy_id: policy.id, asset_type_id: asset_type_ids).map{ |p| [p.asset_type_id, p] }.flatten]
    policy_subtype_rules = Hash[*PolicyAssetSubtypeRule.where(policy_id: policy.id).map{ |p| ["#{p.asset_subtype_id}, #{p.fuel_type_id}", p] }.flatten]

    # store policy rules in a hash for reference later

    AssetType.where(id: asset_type_ids).each do |asset_type|

      # Find all the matching assets for this organization.
      # right now only get assets for SOGR building thus compare assets scheduled replacement year to builder start year
      assets = asset_type.class_name.constantize.replacement_by_policy.where('asset_type_id = ? AND organization_id = ? AND scheduled_replacement_year >= ? AND disposition_date IS NULL AND scheduled_disposition_year IS NULL', asset_type.id, organization.id, @start_year)

      assets += asset_type.class_name.constantize.replacement_underway.where('asset_type_id = ? AND organization_id = ?', asset_type.id, organization.id)

      # Process each asset in turn...
      assets.each do |a|
        policy_analyzer = policy_type_rules[asset_type.id].attributes.merge(policy_subtype_rules["#{a.asset_subtype_id}, #{a.fuel_type_id}"].attributes)
        if policy_analyzer['replace_asset_subtype_id'].present? || policy_analyzer['replace_fuel_type_id'].present?
          policy_analyzer =
              policy_type_rules[asset_type.id].attributes
                  .merge(
                      policy_subtype_rules["#{a.asset_subtype_id}, #{a.fuel_type_id}"].attributes.select{|k,v| k.starts_with?("replace_")}
                  )
                  .merge(
                      policy_subtype_rules["#{(policy_analyzer['replace_asset_subtype_id'] || a.asset_subtype_id)}, #{(policy_analyzer['replace_fuel_type_id'] || a.fuel_type_id)}"].attributes.select{|k,v| !k.starts_with?("replace_")}
                  )
        end
        # reset scheduled replacement year
        a.scheduled_replacement_year = nil if a.replacement_by_policy?
        a.update_early_replacement_reason

        # do the work...
        process_asset(a, @start_year, @last_year, @replacement_project_type, @rehabilitation_project_type, policy_analyzer)
        #a.reload
      end

      # Get the next asset type
    end



  end

  #-----------------------------------------------------------------------------
  # Process a single asset adding it to replacement and rehabilitation projects as
  # needed. Projects are created if they don't already exists otherwise the
  # asset is added to existing projects
  #-----------------------------------------------------------------------------
  def process_asset(asset, start_year, last_year, replacement_project_type, rehabilitation_project_type, policy_analyzer=nil, target_year=nil, current_ali=nil)

    Rails.logger.debug "Processing asset #{asset.object_key}, start_year = #{start_year}, last_year = #{last_year}, #{replacement_project_type}, #{rehabilitation_project_type}, target_year=#{target_year}"

    projects_and_alis = []

    #---------------------------------------------------------------------------
    # Get the policy analyzer for this asset. If the policy is not configured
    # correctly we may miss a rule so we check first to avoid nastiness
    #---------------------------------------------------------------------------
    if policy_analyzer.nil?
      asset_policy_analyzer = asset.policy_analyzer

      if asset_policy_analyzer.get_replace_asset_subtype_id.present? || asset_policy_analyzer.get_replace_fuel_type_id.present?
        policy_analyzer = asset_policy_analyzer.asset_type_rule.attributes.merge(asset_policy_analyzer.asset_subtype_rule.attributes.select{|k,v| k.starts_with?("replace_")}).merge(asset_policy_analyzer.replace_asset_subtype_rule.attributes.select{|k,v| !k.starts_with?("replace_")})
      else
        policy_analyzer = asset_policy_analyzer.asset_type_rule.attributes.merge(asset_policy_analyzer.asset_subtype_rule.attributes)
      end
    end

    #---------------------------------------------------------------------------
    # Initial reset.
    # 1) If the asset has been marked disposed, remove from all SOGR projects after
    #    the disposition date or start date, whichever is first but not before the
    #    first planning year
    # 2) If the asset has been marked for disposal, remove from all SOGR projects after
    #    the scheduled disposition date or start date, whichever is first but
    #    not before the first planning year
    # 3) Remove the asset from any existing SOGR ALIs if the FY year is greater than
    #    or equal to the starting FY year for this analysis.
    #---------------------------------------------------------------------------
    if current_ali.nil?
      if asset.disposed?
        # start date is the later of the FY the asset was disposed and the current
        # planning year
        start_fy_year = [fiscal_year_year_on_date(asset.disposition_date), current_planning_year_year].max
      elsif asset.scheduled_for_disposition?
        # start date is the later of the FY the asset is scheduled for disposal
        # and the current planning year
        start_fy_year = [asset.scheduled_disposition_year, current_planning_year_year].max
      else
        # Start year is infinite
        start_fy_year = 9999
      end

      # save notional ALIs from replacement ALI's before the start fy
      # if asset.activity_line_items.where('fy_year < ?', [start_year, start_fy_year].min).count > 0
      #   untouched_notional_alis = asset.activity_line_items.ids
      # end

      asset.activity_line_items.where('fy_year >= ?', [start_year, start_fy_year].min).each do |ali|
        if ali.capital_project.sogr?
          Rails.logger.debug "deleting asset #{asset.object_key} from ALI #{ali.object_key}"
          ali.assets.delete asset
        end
      end
    else
      Rails.logger.debug "deleting asset #{asset.object_key} from ALI #{current_ali.object_key}"
      current_ali.assets.delete asset
    end

    # Can't build projects for assets that have been scheduled for disposition or already disposed
    if asset.disposed? or asset.scheduled_for_disposition? or asset.no_replacement?
      Rails.logger.info "Asset #{asset.object_key} has been scheduled for disposition or no replacement. Nothing to do."
      return
    end

    #---------------------------------------------------------------------------
    # Step 1: Data consistency check
    #---------------------------------------------------------------------------
    unless asset.replacement_underway?
      unless asset_data_consistency_check(asset, start_year, policy_analyzer['replace_with_new'])
        Rails.logger.info "Asset #{asset.object_key} did not pass data consistency check."
        return
      end
    end

    #---------------------------------------------------------------------------
    # Step 2: Process initial rehabilitation (this happens here only if
    # the initial rehab happens before the initial replacement)
    #---------------------------------------------------------------------------


    # Get the replacement and rehab ALI codes for this asset. If the policy rule
    # specifies leased we need the lease
    if policy_analyzer['replace_with_leased']
      replace_ali_code = TeamAliCode.find_by(:code => policy_analyzer['lease_replacement_code'])
    else
      replace_ali_code = TeamAliCode.find_by(:code => policy_analyzer['purchase_replacement_code'])
    end
    rehab_ali_code = TeamAliCode.find_by(:code => policy_analyzer['rehabilitation_code'])

    # See if the policy requires scheduling rehabilitations.
    rehab_month = policy_analyzer['rehabilitation_service_month'].to_i
    process_rehabs = (rehab_month.to_i > 0)
    extended_years = policy_analyzer['extended_service_life_months'].to_i / 12

    # If the asset has already been scheduled for a rehab, add this to the plan
    if asset.scheduled_rehabilitation_year.present?
      projects_and_alis << add_to_project(asset.organization, asset, rehab_ali_code, asset.scheduled_rehabilitation_year, rehabilitation_project_type, true, false)
      year = asset.scheduled_replacement_year + extended_years
    else
      year = asset.scheduled_replacement_year
    end

    # get interval for notional projects
    min_service_life_years = (policy_analyzer['replace_with_new'] ? policy_analyzer['min_service_life_months'].to_i : policy_analyzer['min_used_purchase_service_life_months'].to_i) / 12
    # Factor in any additional years based on a rehab
    min_service_life_years += extended_years

    Rails.logger.debug "Replacement year = #{year}, min_service_life_years = #{min_service_life_years} for asset #{asset.object_key}"
    unless year < start_year or year > last_year

      #-------------------------------------------------------------------------
      # Step 3: Process initial replacement and rehab
      #-------------------------------------------------------------------------

      unless asset.replacement_underway?
        # Add the initial replacement. If the project does not exist it is created
        projects_and_alis << add_to_project(asset.organization, asset, replace_ali_code, year, replacement_project_type, true, false, policy_analyzer['replace_fuel_type_id'])

        if process_rehabs
          rehab_year = year + (rehab_month / 12)
          if rehab_year <= last_year
            projects_and_alis << add_to_project(asset.organization, asset, rehab_ali_code, rehab_year, rehabilitation_project_type, true, true)
          end
        end
      end

      #-------------------------------------------------------------------------
      # Step 4: Process replacement replacements
      #-------------------------------------------------------------------------
      year += min_service_life_years
      Rails.logger.debug "Max Service Life = #{min_service_life_years} Next replacement = #{year}. Last year = #{last_year}"

      while year <= last_year
        # Add a future re-replacement project for the asset
        projects_and_alis << add_to_project(asset.organization, asset, replace_ali_code, year, replacement_project_type, true, true, policy_analyzer['replace_fuel_type_id'])

        if process_rehabs
          rehab_year = year + (rehab_month / 12)
          if rehab_year <= last_year
            projects_and_alis << add_to_project(asset.organization, asset, rehab_ali_code, rehab_year, rehabilitation_project_type, true, true)
          end
        end

        year += min_service_life_years
      end
    end

    projects_and_alis

  end

  #-----------------------------------------------------------------------------
  # Data consistency check
  #
  # Make sure that the asset has a in service date and a scheduled replacement year.
  # If the scheduled replacement year is not set, default it to the policy replacement year
  # or the first planning year if the asset is in backlog
  #
  # start year is the first planning year
  #
  #-----------------------------------------------------------------------------
  def asset_data_consistency_check(asset, start_year, asset_replace_with_new)
    # Set the schedule replacement year to the policy year if it is not already
    # set
    if asset.scheduled_replacement_year.blank?
      # if no scheduled replacement year is set then use the default. If the
      # asset is in backlog set the to start year
      asset.update_column(:scheduled_replacement_year, asset.policy_replacement_year < current_planning_year_year ? current_planning_year_year : asset.policy_replacement_year)
    elsif asset.scheduled_replacement_year < current_planning_year_year
      asset.update_column(:scheduled_replacement_year, current_planning_year_year)
    end

    asset.update_column(:scheduled_replace_with_new, asset_replace_with_new) if asset.scheduled_replace_with_new.blank?

    !([asset.in_service_date, asset.policy_replacement_year, asset.scheduled_replacement_year, asset.scheduled_replace_with_new, asset.scheduled_replacement_cost].include? nil)

    # COMMENT OUT FOR NOW
    # Check to see if the asset has a scheduled rehabilitation year and if so
    # make sure it is rational ie. must be before the replacement year
    # if asset.scheduled_rehabilitation_year.present?
    #   # is it scheduled in the replacement year
    #   if asset.scheduled_rehabilitation_year == asset.scheduled_replacement_year
    #     # Clear the rehab year and let the system recalculate it as needed
    #     asset.scheduled_rehabilitation_year = nil
    #   elsif asset.scheduled_rehabilitation_year < start_year
    #     # it is scheduled before the start year so it is in backlog
    #     asset.scheduled_rehabilitation_year = start_year
    #   end
    # end

  end

  #-----------------------------------------------------------------------------
  # Adds an asset to a capital project. If the project does not
  # exist it is created first. Future projects are projects generated by a
  # replacement of a replacement or rehab of a replacement -- these are dependent
  # on the first event happening so are kept seperate and are not editab;e
  #-----------------------------------------------------------------------------
  def add_to_project(organization, asset, ali_code, year, project_type, sogr=true, notional=false, fuel_type_id=nil)
    Rails.logger.debug "add_to_project: asset=#{asset} ali_code=#{ali_code} year=#{year} project_type=#{project_type}"
    # The ALI project scope is the parent of the ali code so if the ALI code is 11.11.01 (replace 40 ft bus)
    # the scope becomes 11.11.XX (bus replacement project)
    scope = ali_code.parent

    # Decode the scope so we can set the project up
    scope_context = scope.context.split('->')

    # See if there is an existing project for this scope and year
    project = CapitalProject.find_by('organization_id = ? AND team_ali_code_id = ? AND fy_year = ? AND sogr = ? and notional = ?', organization.id, scope.id, year, sogr, notional)
    if project.nil?
      # create this project
      project_title = "#{scope_context[1]}: #{scope_context[2]}: #{scope.name} project"
      project = create_capital_project(organization, year, scope, project_title, project_type, sogr, notional)
      Rails.logger.debug "Created new project #{project.object_key}"
      @project_count += 1
    else
      Rails.logger.debug "Using existing project #{project.object_key}"
    end


    if asset.present?
      not_pinned_alis = ActivityLineItem.distinct.joins(:assets).where('assets.replacement_status_type_id != 4 OR assets.replacement_status_type_id IS NULL')
      if asset.fuel_type_id.present?
        ali = not_pinned_alis.find_by('activity_line_items.capital_project_id = ? AND activity_line_items.team_ali_code_id = ? AND activity_line_items.fuel_type_id = ?', project.id, ali_code.id, (fuel_type_id || asset.fuel_type_id))
      else
        ali = not_pinned_alis.find_by('activity_line_items.capital_project_id = ? AND activity_line_items.team_ali_code_id = ?', project.id, ali_code.id)
      end

      # if there is an exisiting ALI, see if the asset is in it
      if ali
        Rails.logger.debug "Using existing ALI #{ali.object_key}"
        unless asset.activity_line_items.exists?(ali)
          Rails.logger.debug "asset not in ALI, adding it"
          ali.assets << asset
        else
          Rails.logger.debug "asset already in ALI, not adding it"
        end
      else
        # Create the ALI and add it to the project
        ali_name = "#{scope.name} #{ali_code.name} #{asset.fuel_type_id.present? ? (FuelType.find_by(id: fuel_type_id) || asset.fuel_type).to_s : ''} assets"
        if asset.fuel_type_id.present?
          ali = ActivityLineItem.new({:capital_project => project, :name => ali_name, :team_ali_code => ali_code, :fy_year => project.fy_year, :fuel_type_id => (fuel_type_id || asset.fuel_type_id)})
        else
          ali = ActivityLineItem.new({:capital_project => project, :name => ali_name, :team_ali_code => ali_code, :fy_year => project.fy_year})
        end
        ali.save

        # Now add the asset to it if there is one
        ali.assets << asset
        Rails.logger.debug "Created new ALI #{ali.object_key}"
      end
    end

    [project, ali]

  end

  #-----------------------------------------------------------------------------
  # Creates a new capital project
  #-----------------------------------------------------------------------------
  def create_capital_project(org, fiscal_year, ali_code, title, capital_project_type, sogr=true, notional=false)

    project = CapitalProject.new
    project.organization = org
    project.active = true
    project.sogr = sogr
    project.notional = notional
    project.multi_year = false
    project.emergency = false
    project.fy_year = fiscal_year
    project.team_ali_code = ali_code
    project.capital_project_type = capital_project_type
    project.title = title
    if notional == true
      project.description = "Automatically generated by CPT as notional activity that needs to be planned."
      project.justification = "This project is dependent on other replacement/rehabilitation activities being performed."
    else
      project.description = "Automatically generated by CPT. Please provide a detailed description of this capital project."
      project.justification = "To be completed. Please provide a detailed justification for this capital project."
    end

    # add districts to capital project
    project.districts = Organization.get_typed_organization(org).districts

    project.save
    project
  end

  #-----------------------------------------------------------------------------
  #
  # Private Methods
  #
  #-----------------------------------------------------------------------------
  private

end

