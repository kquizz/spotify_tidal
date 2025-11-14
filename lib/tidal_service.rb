class TidalService
  TIDAL_TOKEN_URL = "https://auth.tidal.com/v1/oauth2/token"
  TIDAL_API_BASE = "https://openapi.tidal.com/v2"

  def initialize(client_id: ENV["TIDAL_CLIENT_ID"], client_secret: ENV["TIDAL_CLIENT_SECRET"])
    @client_id = client_id
    @client_secret = client_secret
  end

  def search_track(track_name, artist_name, limit: 10)
    token = fetch_access_token
    return nil unless token

    # URL encode the search query
    query = "#{track_name} #{artist_name}".strip
    encoded_query = URI.encode_www_form_component(query)

    resp = Faraday.get "#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,artists"
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    }

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    # Find the full track details from included
    if tracks.first
      track_id = tracks.first["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      if full_track
        attributes = full_track["attributes"]
        # Add artists from relationships
        relationships = full_track.dig("relationships", "artists", "data") || []
        artists = relationships.map do |rel|
          artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
          artist ? artist["attributes"]["name"] : nil
        end.compact
        attributes["artists"] = artists
        attributes
      else
        tracks.first
      end
    end
  end

  def get_tracks(track_ids)
    track_ids.map { |id| get_track(id) }.compact
  end

  def get_track(track_id)
    token = fetch_access_token
    return nil unless token

    resp = Faraday.get "#{TIDAL_API_BASE}/tracks/#{track_id}", {
      countryCode: "US",
      include: "artists"
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    }

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    attributes = json.dig("data", "attributes")
    if attributes
      # Fetch artists from relationships link
      artists_link = json.dig("data", "relationships", "artists", "links", "self")
      if artists_link
        artists_resp = Faraday.get "#{TIDAL_API_BASE}#{artists_link}&include=artists", {}, {
          "Authorization" => "Bearer #{token}",
          "accept" => "application/vnd/api+json"
        }
        if artists_resp.success?
          artists_json = JSON.parse(artists_resp.body)
          artist_ids = artists_json.dig("data")&.map { |a| a["id"] } || []
          artists = artist_ids.map do |id|
            artist_resp = Faraday.get "#{TIDAL_API_BASE}/artists/#{id}", {
              countryCode: "US"
            }, {
              "Authorization" => "Bearer #{token}",
              "accept" => "application/vnd/api+json"
            }
            if artist_resp.success?
              artist_json = JSON.parse(artist_resp.body)
              artist_json.dig("data", "attributes", "name")
            else
              "Unknown"
            end
          end.compact
          attributes["artists"] = artists
        end
      end
    end
    attributes
  end

  private

  def fetch_access_token
    return nil unless @client_id && @client_secret

    resp = Faraday.post(TIDAL_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      req.body = URI.encode_www_form(grant_type: "client_credentials")
    end

    return nil unless resp.success?
    JSON.parse(resp.body)["access_token"]
  rescue StandardError
    nil
  end
end
