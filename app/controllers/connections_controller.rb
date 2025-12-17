class ConnectionsController < ApplicationController
  def disconnect_spotify
    Current.user.update(spotify_access_token: nil, spotify_refresh_token: nil, spotify_expires_at: nil)
    redirect_back fallback_location: root_path, notice: "Disconnected Spotify."
  end

  def disconnect_tidal
    Current.user.update(tidal_access_token: nil, tidal_refresh_token: nil, tidal_expires_at: nil)
    redirect_back fallback_location: root_path, notice: "Disconnected Tidal."
  end
end
