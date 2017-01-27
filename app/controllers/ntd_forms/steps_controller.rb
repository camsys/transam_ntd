class NtdForms::StepsController < FormAwareController

  include Wicked::Wizard

  before_action :get_form, :only => [:show, :update]

  # Set the breadcrumbs
  add_breadcrumb "Home", :root_path
  add_breadcrumb "Forms", :forms_path

  steps :agency_information
        #:admin_and_maint_facility_inventory,
        #:passenger_and_parking_facility_inventory,
        #:service_vehicle_inventory,
        #:revenue_vehicle_inventory,

  def show

    add_breadcrumb @form_type.name.pluralize(2), form_path(@form_type)
    add_breadcrumb step.to_s.titleize

    # get data for the current form
    # builds the appropritae association / sub-form
    # TODO: use service to query assets and their associated tables
    # where NtdService.get_data runs its queries and returns an array of hashes
    case step
      when :agency_information
        # do nothing
      when :admin_and_maint_facility_inventory
        # @form.ntd_admin_and_maintenance_facilities.build(NtdReportingService.get_data(step))
      when :passenger_and_parking_facility_inventory
        # @form.ntd_passenger_and_parking_facilities.build(NtdReportingService.get_data(step))
      when :service_vehicle_inventory
        # @form.ntd_service_vehicle_fleets.build(NtdReportingService.get_data(step))
      when :revenue_vehicle_inventory
        #@form.ntd_revenue_vehicle_fleets.build(NtdReportingService.revenue_vehicle_fleets(user.organizations))
    end

    @has_prev_step = previous_step

    render_wizard

  end

  def update

    add_breadcrumb @form_type.name.pluralize(2), form_path(@form_type)
    add_breadcrumb "New"


    case step
      when :agency_information
        @form.update_attributes(form_params)
      when :admin_and_maint_facility_inventory
        # @form.ntd_admin_and_maintenance_facilities.create(NtdReportingService.get_data(step))
      when :passenger_and_parking_facility_inventory
        # @form.ntd_passenger_and_parking_facilities.create(NtdReportingService.get_data(step))
      when :service_vehicle_inventory
        # @form.ntd_service_vehicle_fleets.create(NtdReportingService.get_data(step))
      when :revenue_vehicle_inventory
        # @form.ntd_revenue_vehicle_fleets.create(NtdReportingService.get_data(step))
    end

    render_wizard @form
  end

  private

  def get_form
    @form = NtdForm.find_by(:object_key => params[:ntd_form_id])
  end

  def form_params
    params.require(:ntd_form).permit(NtdForm.allowable_params)
  end

  def finish_wizard_path
    get_form
    return form_ntd_form_url(@form_type, @form)
  end

end
