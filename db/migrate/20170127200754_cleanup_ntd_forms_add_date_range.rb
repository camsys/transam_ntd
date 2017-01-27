class CleanupNtdFormsAddDateRange < ActiveRecord::Migration
  def change
    change_column :ntd_revenue_vehicle_fleets, :model_number, :string, :limit => nil
    change_column :ntd_passenger_and_parking_facilities, :parking_measurement_unit, :string

    add_column :ntd_forms, :start_date, :date
    add_column :ntd_forms, :end_date, :date

  end
end
