#encoding: utf-8

# determine if we are using postgres or mysql
is_mysql = (ActiveRecord::Base.configurations[Rails.env]['adapter'].include? 'mysql2')
is_sqlite =  (ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'sqlite3')

#------------------------------------------------------------------------------
#
# Lookup Tables
#
# These are the lookup tables for TransAM NTD
#
#------------------------------------------------------------------------------

forms = [
  {:active => 1,  :name => 'NTD Reporting Form', :roles => "guest,user,admin,manager,transit_manager", :controller => 'ntd_forms', :description => 'NTD Annual Reporting Forms.'}
]

asset_fleet_types = [
    {groups: 'asset_type_id,asset_subtype_id,fta_vehicle_type_id,dedicated,manufacturer_id,other_manufacturer,manufacture_year,fuel_type_id,dual_fuel_type_id,fta_ownership_type_id,fta_funding_type_id',custom_groups: 'primary_fta_mode_type_id,secondary_fta_mode_type_id,direct_capital_responsibility,primary_fta_service_type_id,secondary_fta_service_type_id',label_groups: 'primary_fta_mode_service,manufacturer,manufacture_year', class_name: 'Vehicle',active: true},
    {groups: 'asset_type_id,asset_subtype_id,fta_support_vehicle_type_id,manufacture_year,pcnt_capital_responsibility',custom_groups: 'primary_fta_mode_type_id,secondary_fta_mode_types',label_groups: 'primary_fta_mode_type,manufacture_year',class_name: 'SupportVehicle',active: true},
    {groups: 'asset_type_id,asset_subtype_id,fta_vehicle_type_id,dedicated,manufacturer_id,other_manufacturer,manufacture_year,fuel_type_id,dual_fuel_type_id,fta_ownership_type_id,fta_funding_type_id',custom_groups: 'primary_fta_mode_type_id,secondary_fta_mode_type_id,direct_capital_responsibility,primary_fta_service_type_id,secondary_fta_service_type_id',label_groups: 'primary_fta_mode_service,manufacturer,manufacture_year',class_name: 'RailCar',active: true},
    {groups: 'asset_type_id,asset_subtype_id,fta_vehicle_type_id,dedicated,manufacturer_id,other_manufacturer,manufacture_year,fuel_type_id,dual_fuel_type_id,fta_ownership_type_id,fta_funding_type_id',custom_groups: 'primary_fta_mode_type_id,secondary_fta_mode_type_id,direct_capital_responsibility,primary_fta_service_type_id,secondary_fta_service_type_id',label_groups: 'primary_fta_mode_service,manufacturer,manufacture_year',class_name: 'Locomotive',active: true}
]


puts "======= Processing TransAM NTD Lookup Tables  ======="

lookup_tables = %w{ asset_fleet_types }

lookup_tables.each do |table_name|
  puts "  Loading #{table_name}"
  if is_mysql
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name};")
  elsif is_sqlite
    ActiveRecord::Base.connection.execute("DELETE FROM #{table_name};")
  else
    ActiveRecord::Base.connection.execute("TRUNCATE #{table_name} RESTART IDENTITY;")
  end
  data = eval(table_name)
  klass = table_name.classify.constantize
  data.each do |row|
    x = klass.new(row)
    x.save!
  end
end

#------------------------------------------------------------------------------
#
# Merge Tables
#
# These are merged tables TransAM NTD
#
#------------------------------------------------------------------------------

puts "======= Processing TransAM NTD Merge Tables  ======="

merge_tables = %w{ forms }

merge_tables.each do |table_name|
  puts "  Merging #{table_name}"
  data = eval(table_name)
  klass = table_name.classify.constantize
  data.each do |row|
    x = klass.new(row)
    x.save!
  end
end

puts "======= Processing TransAM NTD Reports  ======="

reports = [
]

table_name = 'reports'
puts "  Merging #{table_name}"
data = eval(table_name)
data.each do |row|
  puts "Creating Report #{row[:name]}"
  x = Report.new(row.except(:belongs_to, :type))
  x.report_type = ReportType.find_by(:name => row[:type])
  x.save!
end
