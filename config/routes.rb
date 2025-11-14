Rails.application.routes.draw do
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
  get "colors", to: "spotify#colors"

  resources :playlists, only: [ :index, :show, :create, :destroy ]
  resources :albums, only: [ :index, :show, :create, :destroy ]
  resources :artists, only: [ :index, :show, :destroy ]
end
