Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :dev do
    get "styleguide", to: "styleguide#show"
  end

  root "courses#index"

  get "about", to: "pages#about"

  resources :courses, only: %i[index show] do
    member do
      get :round, to: "rounds#new"
    end
    resources :rounds, only: :create
  end

  resources :rounds, only: :show, param: :token do
    resource :delivery, only: :create
  end
end
