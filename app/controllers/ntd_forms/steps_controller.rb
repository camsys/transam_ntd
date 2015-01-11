class NtdForms::StepsController < FormAwareController

  include Wicked::Wizard

  before_action :get_form, :only => [:show, :update]

  # Set the breadcrumbs
  add_breadcrumb "Home", :root_path
  add_breadcrumb "Forms", :forms_path

  steps :agency_information,
        :admin_and_maint_facility_inventory,
        :passenger_and_parking_facility_inventory,
        :service_vehicle_inventory,
        :revenue_vehicle_inventory,
        :summary

  def show

    add_breadcrumb @form_type.name.pluralize(2), form_path(@form_type)
    add_breadcrumb "New"
    #add_breadcrumb step

    @has_next_step = next_step?(step)
    @has_prev_step = previous_step?(step)

    render_wizard

  end

  def update

    add_breadcrumb @form_type.name.pluralize(2), form_path(@form_type)
    add_breadcrumb "New"

    @form.update_attributes(form_params)
    render_wizard @form
  end

  private

  def get_form
    @form = NtdForm.find_by(:object_key => params[:ntd_form_id])
  end

  def form_params
    params.require(:ntd_form).permit(NtdForm.allowable_params)
  end

  def redirect_to_finish_wizard
    get_form
    redirect_to form_ntd_form_url(@form_type, @form)
  end

end
