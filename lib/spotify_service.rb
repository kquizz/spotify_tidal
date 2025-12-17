class SpotifyService
  SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
  SPOTIFY_API_BASE = "https://api.spotify.com/v1"

  def initialize(user: nil, client_id: ENV["SPOTIFY_CLIENT_ID"], client_secret: ENV["SPOTIFY_CLIENT_SECRET"], refresh_token: ENV["SPOTIFY_REFRESH_TOKEN"])
    @client_id = client_id
    @client_secret = client_secret
    @refresh_token = refresh_token
    @user = user
  end

  def liked_tracks(limit: 50)
    token = fetch_access_token
    return [] unless token

    resp = Faraday.get "#{SPOTIFY_API_BASE}/me/tracks", { limit: limit }, { "Authorization" => "Bearer #{token}" }
    return [] unless resp.success?

    json = JSON.parse(resp.body)
    json["items"].map do |item|
      track = item["track"]
      {
        id: track["id"],
        name: track["name"],
        artists: track.dig("artists", 0, "name"),
        album: track.dig("album", "name"),
        href: track["external_urls"] && track["external_urls"]["spotify"]
      }
    end
  end

  def user_playlists(user_id, limit: 50)
    token = fetch_access_token
    return [] unless token

    resp = Faraday.get "#{SPOTIFY_API_BASE}/users/#{CGI.escape(user_id)}/playlists", { limit: limit }, { "Authorization" => "Bearer #{token}" }
    return [] unless resp.success?

    json = JSON.parse(resp.body)
    json["items"].select { |p| p["public"] }.map do |p|  # Only public playlists
      {
        id: p["id"],
        name: p["name"],
        owner: p.dig("owner", "display_name"),
        tracks_total: p.dig("tracks", "total"),
        href: p["external_urls"] && p["external_urls"]["spotify"],
        image: p["images"] && p["images"][1] && p["images"][1]["url"]
      }
    end
  end

  def playlist_tracks(playlist_id, limit: 100)
    token = fetch_access_token
    return [] unless token

    all_tracks = []
    offset = 0

    loop do
      resp = Faraday.get "#{SPOTIFY_API_BASE}/playlists/#{playlist_id}/tracks", { limit: limit, offset: offset }, { "Authorization" => "Bearer #{token}" }
      unless resp.success?
        Rails.logger.error("SpotifyService#playlist_tracks: failed to fetch tracks for playlist=#{playlist_id} status=#{resp.status} body=#{resp.body}") if defined?(Rails)
        return nil
      end

      json = JSON.parse(resp.body)
      tracks = json["items"].map do |item|
        track = item["track"]
        next unless track
        {
          id: track["id"],
          name: track["name"],
          artists: track.dig("artists", 0, "name"),
          artist_id: track.dig("artists", 0, "id"),
          album: track.dig("album", "name"),
          album_id: track.dig("album", "id"),
          album_image: track.dig("album", "images", 1, "url"),
          href: track["external_urls"] && track["external_urls"]["spotify"],
          isrc: track["external_ids"] && track["external_ids"]["isrc"]
        }
      end.compact

      all_tracks.concat(tracks)

      # Check if there are more tracks to fetch
      break if json["next"].nil?
      offset += limit
    end

    all_tracks
  end

  def playlists(limit: 50)
    token = fetch_access_token
    return [] unless token

    resp = Faraday.get "#{SPOTIFY_API_BASE}/me/playlists", { limit: limit }, { "Authorization" => "Bearer #{token}" }
    return [] unless resp.success?

    json = JSON.parse(resp.body)
    json["items"].map do |p|
      {
        id: p["id"],
        name: p["name"],
        owner: p.dig("owner", "display_name"),
        tracks_total: p.dig("tracks", "total"),
        href: p["external_urls"] && p["external_urls"]["spotify"]
      }
    end
  end

  private

  def fetch_access_token
    # Prefer refresh token from user if provided
    if @user && @user.spotify_refresh_token.present?
      refresh = @user.spotify_refresh_token
    else
      refresh = @refresh_token
    end

    return nil unless @client_id && @client_secret && refresh

    resp = Faraday.post(SPOTIFY_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      req.body = URI.encode_www_form(grant_type: "refresh_token", refresh_token: refresh)
    end

    return nil unless resp.success?
    body = JSON.parse(resp.body)
    # If user provided token, update user's tokens if present
    if @user && body["access_token"]
      @user.update(
        spotify_access_token: body["access_token"],
        spotify_expires_at: Time.current + body["expires_in"].to_i.seconds
      )
      @user.update(spotify_refresh_token: body["refresh_token"]) if body["refresh_token"].present?
    end
    body["access_token"]
  rescue StandardError
    nil
  end
end
