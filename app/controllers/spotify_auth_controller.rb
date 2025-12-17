class SpotifyAuthController < ApplicationController
  def request_authorization
    query_params = {
      client_id: ENV["SPOTIFY_CLIENT_ID"],
      response_type: "code",
      redirect_uri: spotify_callback_url,
      scope: "user-read-private playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private",
    }
    redirect_to "https://accounts.spotify.com/authorize?#{query_params.to_query}", allow_other_host: true
  end

  def callback
    if params[:code]
      service = SpotifyService.new
      tokens = exchange_code_for_token(params[:code])

      if tokens
        Current.user.update!(
          spotify_access_token: tokens["access_token"],
          spotify_refresh_token: tokens["refresh_token"],
          spotify_expires_at: Time.current + tokens["expires_in"].to_i.seconds
        )
        redirect_to root_path, notice: "Successfully connected to Spotify!"
      else
        redirect_to root_path, alert: "Failed to connect to Spotify."
      end
    else
      redirect_to root_path, alert: "Spotify authentication failed."
    end
  end

  private

  def spotify_callback_url
    "#{request.base_url}/auth/spotify/callback"
  end

  def exchange_code_for_token(code)
    resp = Faraday.post(SpotifyService::SPOTIFY_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}")
      req.body = URI.encode_www_form(grant_type: "authorization_code", code: code, redirect_uri: spotify_callback_url)
    end
    return nil unless resp.success?
    JSON.parse(resp.body)
  rescue StandardError
    nil
  end
end
