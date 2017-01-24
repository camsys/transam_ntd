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

  #------------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #------------------------------------------------------------------------------

  # Returns a collection of revenue vehicle fleets by grouping vehicle assets in
  # for the organization on the NTD fleet groups and calculating the totals for
  # the columns which need it
  def revenue_vehicle_fleets(org)

    # # We have to use a native SQL rather than going through the model as
    # # complete models are not returned and the initalizers cause method not found
    # # exceptions.
    asset_type_id = AssetType.where(name: 'Revenue Vehicles').pluck(:id)
    organizations = [org]
    # organizations = org.id


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
        null AS renewal_type,
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
        null AS notes
      FROM
        assets a
      WHERE
        a.asset_type_id IN (#{asset_type_id.join(',')})
      AND
        a.organization_id IN (#{organizations.join(',')})
      GROUP BY
        vehicle_type,
        funding_source,
        manufacture_year,
        renewal_year,
        manufacture_code,
        model_number,
        fuel_type,
        vehicle_length,
        seating_capacity,
        standing_capacity"

    results = ActiveRecord::Base.connection.execute(sql)

    # Convert the results set to an array of hashes
    fleets = []
    results.each do |row|
      fleet = {
        :size => row[1],
        :organization_id => org,
        :asset_type_id => asset_type_id,
        :num_active => row[2],
        :num_ada_accessible => row[3],
        :num_emergency_contingency => row[4],
        :fta_vehicle_type_id => row[5],
        :funding_source => row[6],
        :manufacture_code => row[7],
        :model_number => row[8],
        :manufacture_year => row[9],
        :renewal_year => row[10],
        :renewal_cost => row[11],
        :renewal_type => row[12],
        :renewal_cost_year => row[13],
        :replacement_cost => row[14],
        :replacement_cost_parts => row[15],
        :replacement_cost_warranty => row[16],
        :fuel_type => row[17],
        :vehicle_length => row[18],
        :seating_capacity => row[19],
        :standing_capacity => row[20],
        :total_active_miles_in_period => row[21],
        :avg_lifetime_active_miles => row[22],
        :notes => row[23]
      }
      # calculate the additional properties and merge them into the results
      # hash
      fleets << fleet.merge(calc_fleet_items(fleet))
    end
    fleets
  end

  #------------------------------------------------------------------------------
  #
  # Protected Methods
  #
  #------------------------------------------------------------------------------
  protected

  # Selects the actual vehicles in the fleet and generates the additional data components
  # needed for the report.
  def calc_fleet_items(fleet_group)

    vehicles = Vehicle.where(organization_id: fleet_group[:organization_id], asset_type_id: fleet_group[:asset_type_id], fta_vehicle_type_id: fleet_group[:fta_vehicle_type_id],
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

    puts(vehicles)

    vehicles.each do |vehicle|

      num_active += 1 if vehicle.in_service?
      num_ada_accessible += 1 if vehicle.ada_accessible?
      num_emergency_contingency += 1 if vehicle.fta_emergency_contingency_fleet

      avg_lifetime_active_miles += vehicle.current_mileage if vehicle.in_service?
      total_active_miles_in_period += vehicle.current_mileage if vehicle.in_service?

      replacement_cost += vehicle.estimated_replacement_cost unless vehicle.estimated_replacement_cost.blank?

    end
    {
      :total_active_miles_in_period => total_active_miles_in_period,
      :avg_lifetime_active_miles => avg_lifetime_active_miles / vehicles.count,
      :num_active => num_active,
      :num_ada_accessible => num_ada_accessible,
      :num_emergency_contingency => num_emergency_contingency,
      :replacement_cost => replacement_cost,
      :replacement_cost_year => replacement_cost_year
    }
  end

  #------------------------------------------------------------------------------
  #
  # Private Methods
  #
  #------------------------------------------------------------------------------
  private

end
