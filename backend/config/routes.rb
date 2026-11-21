Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "login", to: "auth#login"
    delete "logout", to: "auth#logout"
    get "me", to: "auth#me"

    resource :account, only: %i[show update] do
      post :regenerate_overlay_token
      put :logo
      delete :logo, action: :remove_logo
    end
    # Every account on the platform (platform admins)
    namespace :admin do
      resources :accounts, only: %i[index create update destroy] do
        post :enter, on: :member
      end
    end

    resources :sponsors, only: %i[index create update destroy] do
      put :order, on: :collection
    end
    resources :users, only: %i[index create update destroy]
    resources :game_types, only: %i[index create update destroy]
    resources :pool_tables, only: %i[index show create update destroy] do
      member do
        post :regenerate_token
        post :clear
      end
    end
    resources :players, only: %i[index show create update destroy]
    resources :teams, only: %i[index show create update destroy] do
      put :roster, on: :member
    end
    resources :tournaments, only: %i[index show create update destroy] do
      member do
        post :start
        post :reset
        post :end_early
      end
      resources :entries, only: %i[create update destroy]
    end
    resources :fixtures, only: :show do
      member do
        post :walkover
        post :add_rubber
        post :substitute
      end
    end
    resources :matches, only: %i[index show create update destroy] do
      member do
        put :lineup
        post :assign
        post :start
        post :score
        post :undo
        post :finish
      end
    end

    # Import from the Federação Portuguesa de Bilhar (portalbilhar.pt)
    scope :fpb, controller: :fpb, as: :fpb do
      get :variants
      get :competitions
      get :teams
      get :athletes
      post :import
      post :sync
    end

    # Public snapshots for OBS overlays (the token is the only key)
    get "overlay/tables/:token", to: "overlays#table"
    get "overlay/all/:token", to: "overlays#all"
  end
end
