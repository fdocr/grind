Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  get "sign_up", to: "registrations#new"

  get "my-rounds", to: "my_rounds#index", as: :my_rounds

  namespace :admin do
    resources :users, only: %i[index show update]
    resources :courses do
      resource :greens, only: %i[edit update], controller: "greens"
      member do
        post :sync_osm
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :dev do
    get "styleguide", to: "styleguide#show"
  end

  get "robots.txt", to: "seo#robots"
  get "sitemap.xml", to: "seo#sitemap", defaults: { format: :xml }, as: :sitemap

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
