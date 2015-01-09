#------------------------------------------------------------------------------
#
# NTD Form
#
# Represents a NTD Reporting Form for Transit Operators for a fiscal year.
#
#------------------------------------------------------------------------------
class NtdForm < ActiveRecord::Base

  # Include the object key mixin
  include TransamObjectKey

  # Include the fiscal year mixin
  include FiscalYear

  # Include the Workflow module
  include TransamWorkflow

  #------------------------------------------------------------------------------
  # Callbacks
  #------------------------------------------------------------------------------
  after_initialize  :set_defaults

  #------------------------------------------------------------------------------
  # Associations
  #------------------------------------------------------------------------------
  # Every form belongs to an organization
  belongs_to  :organization

  # Every form  has a form class
  belongs_to  :form

  # Has 0 or more comments. Using a polymorphic association, These will be removed if the form is removed
  has_many    :comments,    :as => :commentable,  :dependent => :destroy

  #------------------------------------------------------------------------------
  # Validations
  #------------------------------------------------------------------------------
  validates :organization,  :presence => true
  validates :form,          :presence => true
  validates :fy_year,       :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 2012}

  # Form A-1
  #------------------------------------------------------------------------------
  # Salary and Wages
  validates :operator_salary_and_wages,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :vehicle_maintenance_salary_and_wages,   :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :other_salary_and_wages,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  # Casualty & Liability
  validates :services,                :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :purchased_transportation,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :fuel_and_lubricants,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :parts_and_repairs,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :other_material_and_supplies,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :utilities,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  # Non-Personal Services
  validates :taxes,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :interest,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :lease_and_rentals,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :expense_transfers,                :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :depreciation_private_capital,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :miscellaneous,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :allowance_for_profit,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  # Revenues
  validates :passenger_revenue,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :special_reimbursement,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :charter_contract_revenue,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :non_user_revenue,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :non_stoa_revenue,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  validates :donated_local_match,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :audit_adjustment,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :cash_adjustment,                 :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  # Form A-2
  #------------------------------------------------------------------------------
  validates :revenue_riders_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :revenue_transfers_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :non_revenue_transfers_downstate_only,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :uniticket,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  validates :revenue_riders_non_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :revenue_transfers_non_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  validates :revenue_vehicle_miles_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :non_revenue_and_deadhead_vehicle_miles,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :charter_school_contract_vehicle_miles,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  validates :revenue_vehicle_hours_stoa_eligible,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :non_revenue_and_deadhead_vehicle_hours,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :charter_school_contract_vehicle_hours,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  validates :peak_hour_fleet_requirement,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :total_fleet,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :wheelchair_accessible_vehicles,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :full_compliance_ada_vehicles,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :employee_equivalents,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :total_employee_hours,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  # Form A-1.1
  #------------------------------------------------------------------------------
  validates :section_5307_admin,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :section_5307_operating_assistance,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :section_5307_preventative_maintenance,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :section_5307_associated_capital_maintenance,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :section_5307_capital_cost_of_contracting,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  # Form A-1.2
  #------------------------------------------------------------------------------
  validates :state_match_to_admin,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :state_match_to_pm,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :state_match_to_acm,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :state_match_to_ccoc,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :cmaq,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :stp,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :miscellaneous,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :wtw_job_access,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :state_miscellaneous_1,              :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates :state_miscellaneous_2,             :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}

  # Form A-1.3
  #------------------------------------------------------------------------------

  # Form A-1.4
  #------------------------------------------------------------------------------

  #------------------------------------------------------------------------------
  # Scopes
  #------------------------------------------------------------------------------

  #------------------------------------------------------------------------------
  # Constants
  #------------------------------------------------------------------------------

  # List of hash parameters allowed by the controller
  FORM_PARAMS = [
    :organization_id,
    :fy_year,
    :state,

    :operator_salary_and_wages,
    :vehicle_maintenance_salary_and_wages,
    :other_salary_and_wages,

    :services,
    :purchased_transportation,
    :fuel_and_lubricants,
    :parts_and_repairs,
    :other_material_and_supplies,
    :utilities,

    :taxes,
    :interest,
    :lease_and_rentals,
    :expense_transfers,
    :depreciation_private_capital,
    :miscellaneous,
    :allowance_for_profit,

    :passenger_revenue,
    :special_reimbursement,
    :charter_contract_revenue,
    :non_user_revenue,
    :non_stoa_revenue,

    :donated_local_match,
    :audit_adjustment,
    :cash_adjustment,

    :section_5307_admin,
    :section_5307_operating_assistance,
    :section_5307_preventative_maintenance,
    :section_5307_associated_capital_maintenance,
    :section_5307_capital_cost_of_contracting,

    :state_match_to_admin,
    :state_match_to_pm,
    :state_match_to_acm,
    :state_match_to_ccoc,
    :cmaq,
    :stp,
    :miscellaneous,
    :wtw_job_access,
    :state_miscellaneous_1,
    :state_miscellaneous_2
  ]

  #------------------------------------------------------------------------------
  #
  # State Machine
  #
  # Used to track the state of a form through the approval process
  #
  #------------------------------------------------------------------------------
  state_machine :state, :initial => :unsubmitted do

    #-------------------------------
    # List of allowable states
    #-------------------------------

    # initial state. All forms are created in this state
    state :unsubmitted

    # state used to signify it has been submitted and is pending review
    state :pending_review

    # state used to signify that the form has been returned for revision.
    state :returned

    # state used to signify that the form has been approved
    state :approved

    #---------------------------------------------------------------------------
    # List of allowable events. Events transition a Form from one state to another
    #---------------------------------------------------------------------------

    # submit a form for approval. This will place the form in the approvers queue.
    event :submit do

      transition [:unsubmitted, :returned] => :pending_review

    end

    # An approver is returning the form for additional information or changes
    event :return do

      transition [:pending_review] => :returned

    end

    # An approver is approving a form
    event :approve do

      transition [:pending_review] => :approved

    end

    # Callbacks
    before_transition do |form, transition|
      Rails.logger.debug "Transitioning #{form.name} from #{transition.from_name} to #{transition.to_name} using #{transition.event}"
    end
  end

  #------------------------------------------------------------------------------
  #
  # Class Methods
  #
  #------------------------------------------------------------------------------

  def self.allowable_params
    FORM_PARAMS
  end

  #------------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #------------------------------------------------------------------------------

  def to_s
    name
  end

  def name
    fiscal_year(fy_year)
  end

  #------------------------------------------------------------------------------
  #
  # Protected Methods
  #
  #------------------------------------------------------------------------------
  protected

  # Set resonable defaults for a new capital project
  def set_defaults
    self.state ||= "unsubmitted"
    # Set the fiscal year to the current fiscal year which can be different from
    # the calendar year
    self.fy_year ||= current_fiscal_year_year
    # Initialize all the numeric fields to 0 so the validations don't complain during the wizard steps
    self.attributes.except("id", "form_id", "created_at", "updated_at", "organization_id", "state", "fy_year", "object_key").keys.each {|x| self.send("#{x}=", 0)}
  end

end
