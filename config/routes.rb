Rails.application.routes.draw do
  root "home#index"

  resource :session
  resource :profile, only: :show
  resources :passwords, param: :token

  namespace :reporting do
    resources :report_templates do
      member do
        patch :publish
        patch :archive
      end
      resources :report_template_items, only: [ :new, :create, :edit, :update, :destroy ]
    end

    resources :reports do
      member do
        patch :publish
        patch :take_in_progress
        patch :submit
        patch :accept
        patch :reject
        patch :reopen
        get  :pdf
        post :regenerate_pdf
      end
      resources :report_items, only: [ :edit, :update ] do
        member do
          get  :edit_grade
          patch :grade
        end
      end
      resources :report_comments, only: [ :create, :destroy ], as: :comments
    end

    resources :reporters, only: [ :index, :show ]
  end

  namespace :dormitory do
    get "dashboard", to: "dashboard#index"
    resources :buildings
    resources :rooms do
      collection do
        get :suggest_number
        get :available
      end
    end
    resources :residents do
      collection do
        get :check_ticket
      end
    end
    resources :accommodations, only: [ :index, :new, :create, :show, :edit, :update ] do
      member do
        get :new_transfer
        patch :transfer
        get :new_eviction
        patch :evict
      end
    end
    resources :academic_years
    resources :batch_evictions, only: [ :index, :new, :create, :show ]

    get "exports/settled_residents", to: "exports/settled_residents#index", as: :exports_settled_residents
    get "exports/free_slots",         to: "exports/free_slots#index",         as: :exports_free_slots
    get "exports/history",            to: "exports/accommodation_histories#index", as: :exports_history
    get "exports/occupancy_stats",    to: "exports/occupancy_stats#index",     as: :exports_occupancy_stats
  end

  resources :notifications, only: [ :index ] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
    end
  end

  resources :activity_feed, only: [ :index ]

  namespace :admin do
    resources :users do
      member do
        patch :activate
        patch :deactivate
        patch :reset_password
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
