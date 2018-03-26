Rails.application.routes.draw do

  resources :asset_fleets do
    collection do
      get 'orphaned_assets'

      get 'new_asset'
      get 'add_asset'

      get 'builder'
      get 'runner'
    end

    member do
      delete 'remove_asset'
    end

  end

  # NTD Forms Controllers
  resources :forms, :only => [] do
    resources :ntd_forms do

      # Build controller for form wizard
      resources :steps, controller: 'ntd_forms/steps'

      collection do
        get   'download_file'
      end

      member do
        get 'fire_workflow_event'
        get 'generate'
      end

      resources :comments

    end
  end
  
end
