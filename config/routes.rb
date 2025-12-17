Rails.application.routes.draw do
  get "queue/index"
  get "artists/index"
  get "artists/show"
  get "artists/destroy"
  get "albums/index"
  get "albums/show"
  get "albums/create"
  get "playlists/index"
  get "playlists/show"
  get "playlists/create"
  resource :registration, only: [ :new, :create ]
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get "/auth/tidal", to: "tidal_auth#request_authorization"
  get "/auth/tidal/callback", to: "tidal_auth#callback"
  get "/auth/spotify", to: "spotify_auth#request_authorization"
  get "/auth/spotify/callback", to: "spotify_auth#callback"

  post "/disconnect/spotify", to: "connections#disconnect_spotify", as: :disconnect_spotify
  post "/disconnect/tidal", to: "connections#disconnect_tidal", as: :disconnect_tidal

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root to: "spotify#index"
  get "spotify", to: "spotify#index"
  get "spotify/playlist/:id", to: "spotify#show", as: :spotify_playlist

  get "sync", to: "spotify#sync"
  post "sync/compare", to: "spotify#compare", as: :compare_sync
  post "sync/sync_all", to: "spotify#sync_all", as: :sync_all
  get "queue", to: "queue#index"

  resources :playlists, only: [ :index, :show, :create, :destroy ] do
    member do
      post :retry_import
      post :sync_to_tidal
      post :lookup_tracks
    end
    collection do
      post :retry_all_failed_imports
    end
  end
  resources :albums, only: [ :index, :show, :create, :destroy ]
  resources :artists, only: [ :index, :show, :destroy ]
end
