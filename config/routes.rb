Rails.application.routes.draw do

  # NTD Forms Controllers
  resources :forms, :only => [] do
    resources :ntd_forms do

      # Build controller for form wizard
      resources :steps, controller: 'ntd_forms/steps'

      member do
        get 'fire_workflow_event'
      end

      resources :comments

    end
  end
  
end
