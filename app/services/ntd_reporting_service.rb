#------------------------------------------------------------------------------
#
# NTD Reporting Service
#
# Manages business logic for generating NTD reports for an organization
#
#
#------------------------------------------------------------------------------
class NtdReportingService

  include FiscalYear

  def initialize(params)
    @form = params[:form]
  end

  #------------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #------------------------------------------------------------------------------

  # Returns a collection of revenue vehicle fleets by grouping vehicle assets in
  # for the organization on the NTD fleet groups and calculating the totals for
  # the columns which need it
  def revenue_vehicle_fleets(orgs)
    asset_type_id = AssetType.where(name: 'Revenue Vehicles').pluck(:id)
    organizations = []

    orgs.each { |o|
      organizations << o.id
    }

    revenue_fleet_report_builder(asset_type_id, organizations)
  end

  # Returns a collection of service vehicle fleets by grouping vehicle assets in
  # the organizations on the NTD fleet groups and calculating the totals for
  # the columns which need it the grouping in this case will be the same as revenue
  # because the current document has no guidelines for groupind service vehicles.
  def service_vehicle_fleets(orgs)
    asset_type_id = AssetType.where(name: 'Support Vehicles').pluck(:id)
    organizations = []

    orgs.each { |o|
      organizations << o.id
    }

    service_fleet_report_builder(asset_type_id, organizations)
  end

  def passenger_and_parking_facilities(orgs)
    asset_type_id = AssetType.where(name: 'Stations/Stops/Terminals').pluck(:id)
    organizations = []

    orgs.each { |o|
      organizations << o.id
    }

    passenger_and_parking_facilities_report_builder(asset_type_id, organizations)
  end

  def admin_and_maintenance_facilities(orgs)
    asset_type_id = AssetType.where(name: 'Support Facilities').pluck(:id)
    organizations = []

    orgs.each { |o|
      organizations << o.id
    }

    admin_and_maintenance_facilities_report_builder(asset_type_id, organizations)
  end


  def revenue_fleet_report_builder(asset_type_id, organization_ids)
    results = fleet_query(asset_type_id, organization_ids)

    # Convert the results set to an array of hashes
    fleets = []
    results.each do |row|
      fleet = {
        :size => row[1],
        :num_active => row[2],
        :num_ada_accessible => row[3],
        :num_emergency_contingency => row[4],

        :model_number => row[8],
        :manufacture_year => row[9],
        :renewal_year => row[10],
        :renewal_cost => row[11],

        :renewal_cost_year => row[13],
        :replacement_cost => row[14],
        :replacement_cost_parts => row[15],
        :replacement_cost_warranty => row[16],

        :vehicle_length => row[18],
        :seating_capacity => row[19],
        :standing_capacity => row[20],
        :total_active_miles_in_period => row[21],
        :avg_lifetime_active_miles => row[22],
        :notes => row[23],

        # These could all be populated via SQL if we wanted to go just get the name or code column for these.
        :vehicle_type => FtaVehicleType.find_by(id: row[5]).code,
        :funding_source => FundingSource.find_by(id: row[6]).to_s,
        :manufacture_code => Manufacturer.find_by(id: row[7]).code,
        :renewal_type => VehicleRebuildType.find_by(id: row[12]).to_s,
        :fuel_type => FuelType.find_by(id: row[17]).to_s
      }
      # calculate the additional properties and merge them into the results
      # hash
      fleets << NtdRevenueVehicleFleet.new(calc_revenue_fleet_items(fleet, organization_ids, asset_type_id))
    end
    fleets
  end


  def service_fleet_report_builder(asset_type_id, organization_ids)
    results = fleet_query(asset_type_id, organization_ids)

    # Convert the results set to an array of hashes
    fleets = []
    results.each do |row|
      fleet = {
          :size => row[1],
          :num_active => row[2],
          :num_ada_accessible => row[3],
          :num_emergency_contingency => row[4],

          :model_number => row[8],
          :manufacture_year => row[9],
          :renewal_year => row[10],
          :renewal_cost => row[11],

          :renewal_cost_year => row[13],
          :replacement_cost => row[14],
          :replacement_cost_parts => row[15],
          :replacement_cost_warranty => row[16],

          :vehicle_length => row[18],
          :seating_capacity => row[19],
          :standing_capacity => row[20],
          :total_active_miles_in_period => row[21],
          :avg_lifetime_active_miles => row[22],
          :notes => row[23],
          :pcnt_capital_responsibility => row[24],
          :estimated_cost_year => row[25],

          # These could all be populated via SQL if we wanted to go just get the name or code column for these.
          :vehicle_type => FtaVehicleType.find_by(id: row[5]).code,
          :funding_source => FundingSource.find_by(id: row[6]).to_s,
          :manufacture_code => Manufacturer.find_by(id: row[7]).code,
          :renewal_type => VehicleRebuildType.find_by(id: row[12]).to_s,
          :fuel_type => FuelType.find_by(id: row[17]).to_s
      }
      # calculate the additional properties and merge them into the results
      # hash
      fleets << NtdServiceVehicleFleet.new(calc_service_fleet_items(fleet, organization_ids, asset_type_id))
    end
    fleets
  end

  def passenger_and_parking_facilities_report_builder(asset_type_id, organizations)
    result = transit_facilities_query(asset_type_id, organizations)

    facilities = []
    result.each { |r|
      primary_fta_mode_type = FtaModeType.find_by(id: r.primary_fta_mode_type_id)
      condition_update = r.condition_updates.where('event_date >= ? AND event_date <= ?', @form.start_date, @form.end_date).last
      facility = {
          :name => r.description,
          :part_of_larger_facility => r.section_of_larger_facility,
          :address => r.address1,
          :city => r.city,
          :state => r.state,
          :zip => r.zip,
          :latitude => r.geometry.nil? ? nil : r.geometry.y,
          :longitude => r.geometry.nil? ? nil : r.geometry.x,
          :primary_mode => primary_fta_mode_type ? "#{primary_fta_mode_type.code} - #{primary_fta_mode_type.name}" : "",
          :facility_type => r.fta_facility_type.to_s,
          :year_built => r.rebuild_year.nil? ? r.manufacture_year : r.rebuild_year ,
          :size => r.facility_size,
          :size_type => 'Square Feet',
          :pcnt_capital_responsibility => r.pcnt_capital_responsibility,
          :estimated_cost => r.estimated_replacement_cost,
          :estimated_cost_year => r.estimated_replacement_year,
          :reported_condition_rating => condition_update ? (condition_update.assessed_rating+0.5).to_i : nil,
          :reported_condition_date => condition_update.event_date,
          :parking_measurement => r.num_parking_spaces_public,
          :parking_measurement_unit => 'Parking Spaces',
          :facility_object_key => r.object_key
      }

      facilities << NtdPassengerAndParkingFacility.new(facility)
    }

    facilities
  end

  def admin_and_maintenance_facilities_report_builder(asset_type_id, organizations)
    result = support_facilities_query(asset_type_id, organizations)

    facilities = []
    result.each { |r|
      primary_fta_mode_type = FtaModeType.find_by(id: r.primary_fta_mode_type_id)
      condition_update = r.condition_updates.where('event_date >= ? AND event_date <= ?', @form.start_date, @form.end_date).last
      facility = {
          :name => r.description,
          :part_of_larger_facility => r.section_of_larger_facility,
          :address => r.address1,
          :city => r.city,
          :state => r.state,
          :zip => r.zip,
          :latitude => r.geometry.nil? ? nil : r.geometry.y,
          :longitude => r.geometry.nil? ? nil : r.geometry.x,
          :primary_mode => primary_fta_mode_type ? "#{primary_fta_mode_type.code} - #{primary_fta_mode_type.name}" : "",
          :facility_type => r.fta_facility_type.to_s,
          :year_built => r.rebuild_year.nil? ? r.manufacture_year : r.rebuild_year ,
          :size => r.facility_size,
          :size_type => 'Square Feet',
          :pcnt_capital_responsibility => r.pcnt_capital_responsibility,
          :estimated_cost => r.estimated_replacement_cost,
          :estimated_cost_year => r.estimated_replacement_year,
          :reported_condition_rating => condition_update ? (condition_update.assessed_rating+0.5).to_i : nil,
          :reported_condition_date => condition_update.event_date,
          :facility_object_key => r.object_key
      }

      facilities << NtdAdminAndMaintenanceFacility.new(facility)
    }

    facilities
  end
  #------------------------------------------------------------------------------
  #
  # Protected Methods
  #
  #------------------------------------------------------------------------------
  protected

  # Selects the actual vehicles in the fleet and generates the additional data components
  # needed for the report. I think this could all be done in SQL and would save us a lot of queries and time.
  def calc_revenue_fleet_items(fleet_group, organization_ids, asset_type_id)

     vehicles = Vehicle.where(organization_id: organization_ids, asset_type_id: asset_type_id, fta_vehicle_type_id: fleet_group[:vehicle_type],
                       fta_funding_type_id: fleet_group[:funding_source], manufacturer_id: fleet_group[:manufacture_code], manufacturer_model: fleet_group[:model_number],
                       manufacture_year: fleet_group[:manufacture_year], rebuild_year: fleet_group[:renewal_year], fuel_type_id: fleet_group[:fuel_type],
                       vehicle_length: fleet_group[:vehicle_length], seating_capacity: fleet_group[:seating_capacity], standing_capacity: fleet_group[:standing_capacity])

    num_active = 0
    num_ada_accessible = 0
    num_emergency_contingency = 0
    total_active_miles_in_period = 0
    avg_lifetime_active_miles = 0
    replacement_cost = 0
    replacement_cost_year = current_fiscal_year_year

    vehicles.each do |vehicle|

      # TODO rework num_active to make sure it is doing what it should.
      num_active += 1 if vehicle.in_service?
      num_ada_accessible += 1 if vehicle.ada_accessible?
      num_emergency_contingency += 1 if vehicle.fta_emergency_contingency_fleet
      avg_lifetime_active_miles += vehicle.current_mileage if vehicle.in_service?
      total_active_miles_in_period += vehicle.current_mileage if vehicle.in_service?
      replacement_cost += vehicle.estimated_replacement_cost unless vehicle.estimated_replacement_cost.blank?
    end

    # It might be better to capture these at a higher level like in the query but the logic around these might be a little convoluted
     if vehicles.first
      fleet_group[:additional_fta_mode] = vehicles.first.fta_mode_types.size > 1 ? vehicles.first.fta_mode_types[1] : nil
      fleet_group[:useful_life_remaining] = vehicles.first.policy_replacement_year - current_fiscal_year_year
     end

    fleet_group[:total_active_miles_in_period] = total_active_miles_in_period
    fleet_group[:avg_lifetime_active_miles] =  num_active > 0 ? avg_lifetime_active_miles / num_active : 0
    fleet_group[:num_active] = num_active
    fleet_group[:num_ada_accessible] = num_ada_accessible
    fleet_group[:num_emergency_contingency] = num_emergency_contingency
    fleet_group[:replacement_cost] = replacement_cost
    fleet_group[:replacement_cost_year] = replacement_cost_year

    fleet_group
  end


  def calc_service_fleet_items(fleet_group, organization_ids, asset_type_id)
    vehicles = SupportVehicle.where(organization_id: organization_ids, asset_type_id: asset_type_id, fta_vehicle_type_id: fleet_group[:vehicle_type],
                  manufacturer_id: fleet_group[:manufacture_code],  manufacturer_model: fleet_group[:model_number], manufacture_year: fleet_group[:manufacture_year],
                  pcnt_capital_responsibility: fleet_group[:pcnt_capital_responsibility], estimated_replacement_year: fleet_group[:estimated_cost_year])
    replacement_cost = 0

    vehicles.each do |vehicle|
      replacement_cost += vehicle.estimated_replacement_cost
    end

    service_fleet = {
      :size => fleet_group[:size],
      :vehicle_type => fleet_group[:vehicle_type],
      :manufacture_year => fleet_group[:manufacture_year],
      :avg_expected_years => vehicles.first ? vehicles.first.estimated_replacement_year - current_fiscal_year_year : nil,
      :pcnt_capital_responsibility => fleet_group[:pcnt_capital_responsibility],
      :estimated_cost => replacement_cost,
      :estimated_cost_year => fleet_group[:estimated_cost_year]
    }

  end
  #------------------------------------------------------------------------------
  #
  # Private Methods
  #
  #------------------------------------------------------------------------------
  private
  def fleet_query(asset_type_id, organization_ids)
    # We have to use a native SQL rather than going through the model as
    # complete models are not returned and the initalizers cause method not found
    # exceptions.
    sql = "SELECT
        null AS rvi_id,
        count(*) AS 'size',
        null AS 'num_active',
        null AS 'num_ada_accessible',
        null AS 'num_emergency_contingency',
        a.fta_vehicle_type_id AS vehicle_type,
        a.fta_funding_type_id AS funding_source,
        manufacturer_id AS manufacture_code,
        a.manufacturer_model AS model_number,
        a.manufacture_year AS manufacture_year,
        a.rebuild_year AS renewal_year,
        a.vehicle_rebuild_type_id AS renewal_type,
        null AS renewal_cost,
        null AS renewal_cost_year,
        null AS replacement_cost,
        null AS replacement_cost_parts,
        null AS replacement_cost_warranty,
        a.fuel_type_id AS fuel_type,
        a.vehicle_length AS vehicle_length,
        a.seating_capacity AS seating_capacity,
        a.standing_capacity AS standing_capacity,
        null AS total_active_miles_in_period,
        null AS avg_lifetime_active_miles,
        null AS notes,
        a.pcnt_capital_responsibility AS pcnt_capital_responsibility,
        estimated_replacement_year AS estimated_cost_year
      FROM
        assets a
      WHERE
        a.asset_type_id IN (#{asset_type_id.join(',')})
      AND (
        (assets.disposition_date IS NULL AND assets.asset_tag != assets.object_key)
        OR (assets.disposition_date >= #{@form.start_date} AND assets.disposition_date <= #{@form.end_date})
      )
      AND
        a.organization_id IN (#{organization_ids.join(',')})
      GROUP BY
        vehicle_type,
        funding_source,
        manufacture_year,
        renewal_year,
        manufacture_code,
        renewal_type,
        model_number,
        fuel_type,
        vehicle_length,
        seating_capacity,
        standing_capacity,
        pcnt_capital_responsibility"

    ActiveRecord::Base.connection.execute(sql)
  end

  def transit_facilities_query(asset_type_id, organization_ids)
    TransitFacility.where('(assets.disposition_date IS NULL AND assets.asset_tag != assets.object_key) OR (assets.disposition_date >= ? AND assets.disposition_date <= ?)', @form.start_date, @form.end_date).where(asset_type_id: asset_type_id, organization_id: organization_ids)
  end

  def support_facilities_query(asset_type_id, organization_ids)
    SupportFacility.where('(assets.disposition_date IS NULL AND assets.asset_tag != assets.object_key) OR (assets.disposition_date >= ? AND assets.disposition_date <= ?)', @form.start_date, @form.end_date).where('assets.disposition_date IS NULL AND assets.asset_tag != assets.object_key').where(asset_type_id: asset_type_id, organization_id: organization_ids)
  end




end
