class RenameTableNtdReveueVehicleFleets < ActiveRecord::Migration
  def change
    rename_table :ntd_reveue_vehicle_fleets, :ntd_revenue_vehicle_fleets
  end
end

