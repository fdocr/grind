Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create destroy]
  get "sign_up", to: "registrations#new"

  get "dashboard", to: "dashboard#show"
  get "dashboard/rounds", to: "dashboard#rounds", as: :dashboard_rounds
  get "my-rounds", to: redirect("/dashboard")

  get "account/password", to: "account#edit_password", as: :edit_account_password
  patch "account/password", to: "account#update_password", as: :update_account_password

  namespace :admin do
    resources :users, only: %i[index show update]
    resources :contributions, only: %i[index show update]
    resources :courses do
      resource :greens, only: %i[edit update], controller: "greens"
      member do
        post :sync_osm
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # Deep-link association files for the Hotwire Native apps.
  get "/.well-known/apple-app-site-association" => "well_known#aasa"
  get "/.well-known/assetlinks.json" => "well_known#assetlinks"

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
  get "privacy", to: "pages#privacy"

  get "contribute", to: "contributions#new", as: :contribute
  post "contribute", to: "contributions#create"

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
