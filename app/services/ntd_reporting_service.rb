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
  # Instantcs Methods
  #
  #------------------------------------------------------------------------------

  # Returns a collection of revenue vehicle fleets by grouping vehicle assets in
  # for the organization on the NTD fleet groups and calculating the totals for
  # the columns which need it
  def revenue_vehicle_fleets(org)

    # We have to use a native SQL rather than going through the model as
    # complete models are not returned and the initalizers cause method not found
    # exceptions.
    results = ActiveRecord::Base.connection.execute(%q{
      SELECT
      count(*) AS 'size',
      a.fta_vehicle_type_id,
      a.fta_funding_type_id,

      a.manufacture_year,
      a.rebuild_year,
      a.manufacturer_id,
      a.manufacturer_model,
      fuel_type_id,
      a.vehicle_length,
      a.seating_capacity,
      a.standing_capacity
      FROM
      assets a
      WHERE
      a.asset_type_id = 1
      AND a.organization_id = 6
      GROUP BY
      a.fta_vehicle_type_id,
      a.fta_funding_type_id,
      a.manufacture_year,
      a.rebuild_year,
      a.manufacturer_id,
      a.manufacturer_model,
      a.fuel_type_id,
      a.vehicle_length,
      a.seating_capacity,
      a.standing_capacity
      })

    # Convert the results set to an array of hashes
    fleets = []
    results.each do |row|
      fleet = {
        :organization_id => org.id,
        :asset_type_id => 1,
        :size => row[0],
        :fta_vehicle_type_id => row[1],
        :fta_funding_type_id => row[2],
        :manufacture_year => row[3],
        :rebuild_year => row[4],
        :manufacturer_id => row[5],
        :manufacturer_model => row[6],
        :fuel_type_id => row[7],
        :vehicle_length => row[8],
        :seating_capacity => row[9],
        :standing_capacity => row[10]
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

    vehicles = Vehicle.where(fleet_group.except(:size))
    total_active_miles_in_period = 0
    avg_lifetime_active_miles = 0
    num_active = 0
    num_ada_accessible = 0
    num_emergency_contingency = 0
    replacement_cost = 0
    replacement_cost_year = current_fiscal_year_year

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
