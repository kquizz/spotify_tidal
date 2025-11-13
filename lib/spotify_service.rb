class SpotifyService
  SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
  SPOTIFY_API_BASE = "https://api.spotify.com/v1"

  def initialize(client_id: ENV["SPOTIFY_CLIENT_ID"], client_secret: ENV["SPOTIFY_CLIENT_SECRET"], refresh_token: ENV["SPOTIFY_REFRESH_TOKEN"])
    @client_id = client_id
    @client_secret = client_secret
    @refresh_token = refresh_token
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

    resp = Faraday.get "#{SPOTIFY_API_BASE}/users/#{user_id}/playlists", { limit: limit }, { "Authorization" => "Bearer #{token}" }
    return [] unless resp.success?

    json = JSON.parse(resp.body)
    json["items"].select { |p| p["public"] }.map do |p|  # Only public playlists
      {
        id: p["id"],
        name: p["name"],
        owner: p.dig("owner", "display_name"),
        tracks_total: p.dig("tracks", "total"),
        href: p["external_urls"] && p["external_urls"]["spotify"]
      }
    end
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
    return nil unless @client_id && @client_secret && @refresh_token

    resp = Faraday.post(SPOTIFY_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      req.body = URI.encode_www_form(grant_type: "refresh_token", refresh_token: @refresh_token)
    end

    return nil unless resp.success?
    JSON.parse(resp.body)["access_token"]
  rescue StandardError
    nil
  end
end
