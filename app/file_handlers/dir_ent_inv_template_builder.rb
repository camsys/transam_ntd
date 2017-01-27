#-------------------------------------------------------------------------------
#
# TransitInventoryUpdatesTemplateBuilder
#
# Creates a template for capturing status updates for existing transit inventory
# This adds mileage updates to the core inventory builder
#
#-------------------------------------------------------------------------------
class DirEntInvTemplateBuilder < TemplateBuilder

  attr_accessor :ntd_form

  SHEET_NAME = "A-80 DirEntInv"

  protected

  # Add a row for each of the asset for the org
  def add_rows(sheet)

    support_facilities = @ntd_form.ntd_admin_and_maintenance_facilities(Organization.where(id: @organization_list))
    transit_facilities = @ntd_form.ntd_passenger_and_parking_facilities(Organization.where(id: @organization_list))
    support_vehicles = @ntd_form.ntd_service_vehicle_fleets(Organization.where(id: @organization_list))
    rev_vehicles = @ntd_form.ntd_revenue_vehicle_fleets(Organization.where(id: @organization_list))

    row_count = [support_facilities.count, transit_facilities.count, support_vehicles.count, rev_vehicles.count].max

    (0..row_count - 1).each do |idx|

      line = idx+1
      row_data = [line.to_s]

      support_facility = support_facilities[idx]
      if support_facility
        puts support_facility.inspect
        row_data << support_facility.name
        row_data << support_facility.part_of_larger_facility
        row_data << support_facility.address
        row_data << support_facility.city
        row_data << support_facility.state
        row_data << support_facility.zip
        row_data << support_facility.primary_mode
        row_data << support_facility.facility_type
        row_data << support_facility.year_built
        row_data << support_facility.size
        row_data << support_facility.pcnt_capital_responsibility
        row_data << support_facility.reported_condition_rating
        row_data << support_facility.reported_condition_date
        row_data << ''
      else
          row_data << ['']*14
      end
      row_data << ''

      transit_facility = transit_facilities[idx]
      if transit_facility
        row_data << transit_facility.name
        row_data << transit_facility.part_of_larger_facility
        row_data << transit_facility.address
        row_data << transit_facility.city
        row_data << transit_facility.state
        row_data << transit_facility.zip
        row_data << transit_facility.latitude
        row_data << transit_facility.longitude
        row_data << transit_facility.primary_mode
        row_data << transit_facility.facility_type
        row_data << transit_facility.year_built
        row_data << transit_facility.parking_measurement
        row_data << transit_facility.parking_measurement_unit
        row_data << transit_facility.pcnt_capital_responsibility

        row_data << transit_facility.reported_condition_rating
        row_data << transit_facility.reported_condition_date
        row_data << ''
      else
        row_data << ['']*17
      end
      row_data << ''

      row_data << ['']*21
      row_data << ''

      row_data << ['']*7
      row_data << ''

      support_vehicle = support_vehicles[idx]
      if support_vehicle
        row_data << "NAME?"

        row_data << support_vehicle.vehicle_type
        row_data << support_vehicle.size

        row_data << support_vehicle.avg_expected_years
        row_data << support_vehicle.manufacture_year
        row_data << support_vehicle.pcnt_capital_responsibility
        row_data << support_vehicle.estimated_cost
        row_data << support_vehicle.estimated_cost_year
        row_data << ''
      else
        row_data << ['']*9
      end
      row_data << ''

      rev_vehicle = rev_vehicles[idx]
      if rev_vehicle
        row_data << "#{rev_vehicle.manufacture_code}-#{rev_vehicle.model_number}-#{rev_vehicle.manufacture_year}"
        row_data << rev_vehicle.size
        row_data << rev_vehicle.num_active
        row_data << rev_vehicle.num_ada_accessible
        row_data << rev_vehicle.num_emergency_contingency
        row_data << ''
        row_data << rev_vehicle.vehicle_type.code
        row_data << rev_vehicle.funding_source.to_s
        row_data << rev_vehicle.useful_life_remaining
        row_data << rev_vehicle.manufacture_year
        row_data << rev_vehicle.manufacture_code.code
        row_data << rev_vehicle.model_number
        row_data << rev_vehicle.renewal_year
        row_data << rev_vehicle.renewal_type
        row_data << '???'
        row_data << '???'
        row_data << '???'
        row_data << '???'
        row_data << '???'
        row_data << '???'
        row_data << rev_vehicle.fuel_type.code
        row_data << rev_vehicle.vehicle_length
        row_data << rev_vehicle.seating_capacity
        row_data << rev_vehicle.standing_capacity
        row_data << rev_vehicle.total_active_miles_in_period
        row_data << rev_vehicle.avg_lifetime_active_miles
        row_data << rev_vehicle.additional_fta_mode
        row_data << ''
      else
        row_data << ['']*27
      end
      row_data << ''


      sheet.add_row row_data.flatten.map{|x| x.to_s}
    end


  end

  # Configure any other implementation specific options for the workbook
  # such as lookup table worksheets etc.
  def setup_workbook(workbook)

  end

  # Performing post-processing
  def post_process(sheet)

    # protect sheet so you cannot update cells that are locked
    sheet.sheet_protection

    # Merge Cells
    sheet.merge_cells("B1:CX1")
    sheet.merge_cells("B2:O2")
    sheet.merge_cells("Q2:AG2")
    sheet.merge_cells("AI2:BC2")
    sheet.merge_cells("BE2:BK2")
    sheet.merge_cells("BN2:BU2")
    sheet.merge_cells("BW2:CX2")

    title_style = sheet.styles.add_style({:name => 'title', :bg_color => "87aee7", :b => true})
    title_detail_style = sheet.styles.add_style({:b => true})

    (0..101).each do |cell_idx|
      sheet.rows[0].cells[cell_idx].style = title_style
      unless [0, 15, 33, 55, 63, 73].include? cell_idx # columns in between tables
        sheet.rows[1].cells[cell_idx].style = title_style
      end
    end

    sheet.row_style 2, title_detail_style

  end

  # header rows
  def header_rows
    title_row = [
      'Form',
      'Name: Direct Entry Inventory (A-80)'
    ] + ['']*100

    sub_title_row =
        ['', 'Administrative and Maintenance Facility Inventory'] +
        ['']*14 +
        ['Passenger and Parking Facility Inventory'] +
        ['']*17 +
        ['Rail Fixed Guideway Inventory'] +
        ['']*21 +
        ['Track Inventory'] +
        ['']*7 +
        ['Service Vehicle Inventory'] +
        ['']*9 +
        ['Revenue Vehicle Inventory'] +
        ['']*27

    detail_row = [
      'Line No.',
      'Facility Name',
      'Mark "X" if line item is a section of larger facility',
      'Street Address',
      'City',
      'State',
      'Zip Code',
      'Primary Mode Served at Facility',
      'Facility Type',
      'Year Built or Replaced as New',
      'Square Feet',
      'Percent Agency Capital Responsibility',
      'Condition Assessment',
      'Estimate Date of Condition Assessment',
      'Notes',
      '',
      'Facility Name',
      'Mark "X" if line item is a section of larger facility',
      'Street Address',
      'City',
      'State',
      'Zip Code',
      'Lat.',
      'Long.',
      'Primary Mode Served at Facility',
      'Facility Type',
      'Year Built or Replaced as New',
      'Quantity: Square Feet or Parking Spaces',
      'Unit: Square Feet or Parking Spaces',
      'Percent Transit Agency Capital Responsibility',
      'Condition Assessment',
      'Estimate Date of Condition Assessment',
      'Notes',
      '',
      'Primary Mode (Rail)',
      'Guideway Element (excludes track)',
      'Quantity (Leave as Zero if Not Applicable)',
      'Unit',
      'Quantity (Leave as Zero if Not Applicable)',
      'Unit',
      'Average Expected Service Years When New',
      'Allocation Unit: Linear Feet, Track Feet, or % of Total Value',
      'Pre-1920',
      '1920-1929',
      '1930-1939',
      '1940-1949',
      '1950-1959',
      '1960-1969',
      '1970-1979',
      '1980-1989',
      '1990-1999',
      '2000-present',
      'Total Must=Quantity in Column ai or 100%',
      'Percent Transit Agency Capital Responsibility',
      'Notes',
      '',
      'Rail Mode Type',
      'Track Element',
      'Quantity (Leave as Zero if Not Applicable)',
      'Units',
      'Average Expected Service Years When New',
      'Percent Transit Agency Capital Responsibility',
      'Notes',
      '',
      'Service Vehicle Fleet',
      'Type of Service Vehicle',
      'Number of Vehicles in Fleet',
      'Average Expected Service Years When New',
      'Year of Manufacture',
      'Percent Transit Agency Capital Responsibility',
      'Estimated Cost',
      'Yr. Dollar of Estimated Cost',
      'Notes',
      '',
      'RVI ID.',
      'Number of Vehicles in Total Fleet',
      'Number of Active Vehicles in Fleet',
      'Americans with Disabilities Act of 1990 (ADA) Accessible Vehicles',
      'Number of Emergency Contingency Vehicles',
      'Dedicated Fleet',
      'Vehicle Type Code',
      'Funding Source',
      'Average Expected Service Years When New',
      'Year of Manufacture',
      'Manufacturer Code',
      'Model Number',
      'Year of Last Renewal (Leave blank if N/A)',
      'Type of Last Renewal (Leave blank if N/A)',
      'Est. Renewal Cost',
      'Yr. Dollars of Est. Renewal Cost',
      'Est. Replacement Cost',
      'Yr. Dollars of Est. Replacement Cost',
      'Parts',
      'Warranty',
      'Fuel Type Code',
      'Vehicle Length (in feet)',
      'Seating Capacity',
      'Standing Capacity',
      'Total Miles on Active Vehicles During the Period',
      'Average Lifetime Miles per Active Vehicle',
      'Supports Another Mode',
      'Notes'
    ]

    [title_row, sub_title_row, detail_row]
  end

  def column_styles
    styles = [
      # {:name => 'asset_id_col', :column => 0},
      # {:name => 'asset_id_col', :column => 1},
      # {:name => 'asset_id_col', :column => 2},
      # {:name => 'asset_id_col', :column => 3},
      # {:name => 'asset_id_col', :column => 4},
      # {:name => 'asset_id_col', :column => 5},
      #
      # {:name => 'service_status_string_locked', :column => 6},
      # {:name => 'service_status_date_locked',   :column => 7},
      # {:name => 'service_status_string',        :column => 8},
      # {:name => 'service_status_date',          :column => 9},
      #
      # {:name => 'condition_float_locked', :column => 10},
      # {:name => 'condition_date_locked',  :column => 11},
      # {:name => 'condition_float',        :column => 12},
      # {:name => 'condition_date',         :column => 13}
    ]

    styles
  end

  def row_types
    []
    types
  end
  # Merge the base class styles with BPT specific styles
  def styles
    a = []
    a << super

    # Header Styles
    #
    a << {:name => 'string', :bg_color => "87aee7"}

    # a << {:name => 'asset_id_col', :bg_color => "EBF1DE", :fg_color => '000000', :b => false, :alignment => { :horizontal => :left }}
    #
    # a << {:name => 'service_status_string_locked', :bg_color => "F2DCDB", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'service_status_date_locked', :format_code => 'MM/DD/YYYY', :bg_color => "F2DCDB", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'service_status_string', :bg_color => "F2DCDB", :alignment => { :horizontal => :center } , :locked => false }
    # a << {:name => 'service_status_date', :format_code => 'MM/DD/YYYY', :bg_color => "F2DCDB", :alignment => { :horizontal => :center } , :locked => false }
    #
    # a << {:name => 'condition_float_locked', :num_fmt => 2, :bg_color => "DDD9C4", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'condition_date_locked', :format_code => 'MM/DD/YYYY', :bg_color => "DDD9C4", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'condition_float', :num_fmt => 2, :bg_color => "DDD9C4", :alignment => { :horizontal => :center } , :locked => false }
    # a << {:name => 'condition_date', :format_code => 'MM/DD/YYYY', :bg_color => "DDD9C4", :alignment => { :horizontal => :center } , :locked => false }
    #
    # a << {:name => 'mileage_integer_locked', :num_fmt => 3, :bg_color => "DCE6F1", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'mileage_date_locked', :format_code => 'MM/DD/YYYY', :bg_color => "DCE6F1", :alignment => { :horizontal => :center } , :locked => true }
    # a << {:name => 'mileage_integer', :num_fmt => 3, :bg_color => "DCE6F1", :alignment => { :horizontal => :center } , :locked => false }
    # a << {:name => 'mileage_date', :format_code => 'MM/DD/YYYY', :bg_color => "DCE6F1", :alignment => { :horizontal => :center } , :locked => false }

    a.flatten
  end

  def worksheet_name
    SHEET_NAME
  end

  private

  def initialize(*args)
    super
  end

  def include_mileage_columns?
    class_names = @asset_types.map(&:class_name)
    if class_names.include? "Vehicle" or class_names.include? "SupportVehicle"
      true
    else
      false
    end
  end

end
