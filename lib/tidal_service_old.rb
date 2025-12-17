class TidalService
  include ApiErrorHandler

  TIDAL_TOKEN_URL = "https://auth.tidal.com/v1/oauth2/token"
  TIDAL_API_BASE = "https://openapi.tidal.com/v2"

  def initialize(user: nil, client_id: ENV["TIDAL_CLIENT_ID"], client_secret: ENV["TIDAL_CLIENT_SECRET"])
    @user = user
    @client_id = client_id
    @client_secret = client_secret
    @conn = build_faraday_connection(TIDAL_API_BASE, timeout: 45)
  end

  def exchange_code_for_token(code, redirect_uri, code_verifier)
    resp = Faraday.post(TIDAL_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      req.body = URI.encode_www_form(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      )
    end

    return nil unless resp.success?
    JSON.parse(resp.body)
  end

  def search_track(track_name, artist_name, limit: 10, search_log: nil, album_name: nil, isrc: nil)
    token = fetch_access_token
    return nil unless token

    strategies = [
      { method: :search_by_isrc, condition: -> { isrc.present? }, params: [ isrc ] },
      { method: :search_by_artist_album, condition: -> { album_name.present? }, params: [ track_name, artist_name, album_name ] },
      { method: :search_exact_match, condition: -> { true }, params: [ track_name, artist_name ] },
      { method: :search_cleaned_strings, condition: -> { true }, params: [ track_name, artist_name ] },
      { method: :search_primary_artist, condition: -> { true }, params: [ track_name, artist_name ] },
      { method: :search_track_only_with_artist_filter, condition: -> { true }, params: [ track_name, artist_name ] },
      { method: :search_relaxed, condition: -> { true }, params: [ track_name, artist_name ] }
    ]

    strategies.each_with_index do |strategy, index|
      next unless strategy[:condition].call

      log_entry = { strategy: index, type: strategy[:method].to_s }
      search_log << log_entry if search_log

      Rails.logger.info("TidalService: Strategy #{index} (#{strategy[:method]}) - Starting search")

      result = send(strategy[:method], *strategy[:params], token)

      if result
        Rails.logger.info("TidalService: Strategy #{index} Match Found: #{result['title']} by #{result['artists']&.join(', ')}")
        search_log.last[:result] = "match" if search_log
        return result
      else
        Rails.logger.info("TidalService: Strategy #{index} - No match found")
        search_log.last[:result] = "no_match" if search_log
      end
    end

    nil
  end

  private

  # Strategy 0: ISRC search - most accurate
  def search_by_isrc(isrc, token)
    Rails.logger.info("TidalService: Searching by ISRC '#{isrc}'")

    encoded_query = URI.encode_www_form_component(isrc)
    resp = search_tracks(encoded_query, token, limit: 10)
    return nil unless resp

    find_track_by_isrc(resp, isrc)
  end

  # Strategy 1: Artist + Album search - primary strategy for album tracks
  def search_by_artist_album(track_name, artist_name, album_name, token)
    Rails.logger.info("TidalService: Searching by artist '#{artist_name}' + album '#{album_name}'")

    # First try to find the album by searching "artist album"
    album_query = "#{artist_name} #{album_name}".strip
    encoded_query = URI.encode_www_form_component(album_query)

    # Search for albums first
    album_resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/albums", {
      countryCode: "US",
      include: "albums,albums.artists",
      limit: 10
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless album_resp.success?

    album_data = JSON.parse(album_resp.body)
    albums = album_data.dig("data") || []
    included = album_data.dig("included") || []

    # Find best matching album
    best_album = find_best_matching_album(albums, included, album_name, artist_name)
    return nil unless best_album

    # Get tracks from this album
    album_id = best_album["id"]
    tracks_resp = Faraday.get("#{TIDAL_API_BASE}/albums/#{album_id}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 100
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless tracks_resp.success?

    tracks_data = JSON.parse(tracks_resp.body)
    tracks = tracks_data.dig("data") || []
    tracks_included = tracks_data.dig("included") || []

    # Find the specific track by name
    find_track_by_title(tracks, tracks_included, track_name)
  end

  # Strategy 2: Exact track + artist search
  def search_exact_match(track_name, artist_name, token)
    Rails.logger.info("TidalService: Exact search '#{track_name} #{artist_name}'")

    query = "#{track_name} #{artist_name}".strip
    encoded_query = URI.encode_www_form_component(query)
    resp = search_tracks(encoded_query, token)
    return nil unless resp

    find_track_with_artist_match(resp, track_name, artist_name)
  end

  # Strategy 3: Cleaned strings (remove feat, remastered, etc)
  def search_cleaned_strings(track_name, artist_name, token)
    cleaned_track = clean_string(track_name)
    cleaned_artist = clean_string(artist_name)

    return nil if cleaned_track == track_name && cleaned_artist == artist_name

    Rails.logger.info("TidalService: Cleaned search '#{cleaned_track} #{cleaned_artist}'")

    query = "#{cleaned_track} #{cleaned_artist}".strip
    encoded_query = URI.encode_www_form_component(query)
    resp = search_tracks(encoded_query, token)
    return nil unless resp

    find_track_with_artist_match(resp, cleaned_track, cleaned_artist)
  end

  # Strategy 4: Primary artist only (remove featured artists)
  def search_primary_artist(track_name, artist_name, token)
    # Extract primary artist (before "feat", "ft", "&", etc.)
    primary_artist = artist_name.split(/\s+(?:feat\.?|ft\.?|featuring|&|and)\s+/i).first&.strip
    return nil if !primary_artist || primary_artist == artist_name || primary_artist.length < 3

    Rails.logger.info("TidalService: Primary artist search '#{track_name} #{primary_artist}'")

    query = "#{track_name} #{primary_artist}".strip
    encoded_query = URI.encode_www_form_component(query)
    resp = search_tracks(encoded_query, token)
    return nil unless resp

    find_track_with_artist_match(resp, track_name, primary_artist, fuzzy: true)
  end

  # Strategy 5: Track-only search with artist filtering
  def search_track_only_with_artist_filter(track_name, artist_name, token)
    Rails.logger.info("TidalService: Track-only search '#{track_name}' with artist filter")

    encoded_query = URI.encode_www_form_component(track_name)
    resp = search_tracks(encoded_query, token, limit: 50)
    return nil unless resp

    find_track_with_artist_match(resp, track_name, artist_name, fuzzy: true)
  end

  # Strategy 6: Relaxed search with scoring
  def search_relaxed(track_name, artist_name, token)
    Rails.logger.info("TidalService: Relaxed search with scoring")

    encoded_query = URI.encode_www_form_component(track_name)
    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks",
      limit: 50
    }, {
      "Authorization" => "Bearer #{token}"
    })

    return nil unless resp.success?
    json = JSON.parse(resp.body)
    return nil if json["data"].nil? || json["data"].empty?

    included = json["included"] || []
    tracks = included.select { |item| item["type"] == "tracks" }
    return nil if tracks.empty?

    # Find best match by scoring
    best_match = nil
    best_score = 0

    tracks.each do |track|
      title_similarity = calculate_title_similarity(track_name, track["attributes"]["title"])
      artist_names = track["relationships"]["artists"]["data"].map { |a| a["id"] }
      artist_objects = included.select { |item| item["type"] == "artists" && artist_names.include?(item["id"]) }
      artist_str = artist_objects.map { |a| a["attributes"]["name"] }.join(", ")
      artist_similarity = calculate_artist_similarity(artist_name, artist_str)

      score = (title_similarity * 0.7) + (artist_similarity * 0.3)

      if score > best_score && score > 0.5
        best_score = score
        best_match = extract_track_details(track, included)
      end
    end

    best_match
  end

  def clean_string(str)
    str.gsub(/\s*\(.*?\)\s*/, "") # Remove content in parentheses
       .gsub(/\s*\[.*?\]\s*/, "") # Remove content in brackets
       .gsub(/\s*-\s*Remastered.*/i, "") # Remove Remastered
       .gsub(/\s*-\s*Remaster.*/i, "") # Remove Remaster
       .gsub(/\s*-\s*Deluxe.*/i, "") # Remove Deluxe
       .gsub(/\s*-\s*Extended.*/i, "") # Remove Extended
       .gsub(/\s*feat\..*/i, "") # Remove feat.
       .gsub(/\s*ft\..*/i, "") # Remove ft.
       .gsub(/\s*featuring\s+.*/i, "") # Remove featuring
       .strip
  end

  def remove_remix_indicators(str)
    str.gsub(/\s*-?\s*\(.*?remix.*?\)/i, "") # Remove (XXX Remix)
       .gsub(/\s*-?\s*\[.*?remix.*?\]/i, "") # Remove [XXX Remix]
       .gsub(/\s*-?\s*remix\b.*/i, "") # Remove anything after "remix"
       .gsub(/\s*-?\s*\(.*?edit.*?\)/i, "") # Remove (XXX Edit)
       .gsub(/\s*-?\s*edit\b.*/i, "") # Remove anything after "edit"
       .gsub(/\s*-?\s*\(.*?version.*?\)/i, "") # Remove (XXX Version)
       .gsub(/\s*-?\s*version\b.*/i, "") # Remove anything after "version"
       .strip
  end

  def normalize_unicode(str)
    # Map special Unicode characters to their common equivalents
    # This preserves readability while helping with search
    char_map = {
      "\u03A3" => "S",  # Greek capital sigma
      "\u03C3" => "s",  # Greek small sigma
      "\u03C2" => "s",  # Greek final sigma
      "\u03A9" => "O",  # Greek omega
      "\u03C9" => "o",
      "\u0394" => "D",  # Greek delta
      "\u03B4" => "d",
      "\u0398" => "TH", # Greek theta
      "\u03B8" => "th",
      "\u03A6" => "PH", # Greek phi
      "\u03C6" => "ph",
      "\u03A8" => "PS", # Greek psi
      "\u03C8" => "ps",
      "\u03B1" => "a",  # Greek alpha
      "\u03B2" => "b",  # Greek beta
      "\u03B3" => "g",  # Greek gamma
      "\u03B5" => "e",  # Greek epsilon
      "\u03B7" => "e",  # Greek eta
      "\u03B9" => "i",  # Greek iota
      "\u03BA" => "k",  # Greek kappa
      "\u03BB" => "l",  # Greek lambda
      "\u03BC" => "m",  # Greek mu
      "\u03BD" => "n",  # Greek nu
      "\u03BE" => "x",  # Greek xi
      "\u03C0" => "p",  # Greek pi
      "\u03C1" => "r",  # Greek rho
      "\u03C4" => "t",  # Greek tau
      "\u03C5" => "y",  # Greek upsilon
      "\u03C7" => "ch", # Greek chi
      "\u03B6" => "z",  # Greek zeta
      "\u00F1" => "n",  # Spanish ñ
      "\u00FC" => "u",  # German umlaut
      "\u00F6" => "o",
      "\u00E4" => "a",
      "\u00E9" => "e",  # French accents
      "\u00E8" => "e",
      "\u00EA" => "e",
      "\u00E0" => "a",
      "\u00E7" => "c"
    }

    result = str.dup
    char_map.each do |unicode_char, replacement|
      result.gsub!(unicode_char, replacement)
    end
    result
  rescue
    str # If anything fails, return original
  end

  def perform_search(track_name, artist_name, token, swap_mode: false)
    query = "#{track_name} #{artist_name}".strip
    encoded_query = URI.encode_www_form_component(query)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 25
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    if swap_mode
      # In swap mode, we're looking for artist matches since track/artist were swapped
      process_search_response_swap_mode(resp, track_name, artist_name)
    else
      process_search_response(resp, track_name, artist_name)
    end
  end

  def perform_search_track_only(track_name, artist_name, token, fuzzy: false)
    encoded_query = URI.encode_www_form_component(track_name)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 100
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      relationships = full_track.dig("relationships", "artists", "data") || []
      relationships.any? do |rel|
        artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
        next unless artist

        tidal_artist_name = artist["attributes"]["name"]

        if fuzzy
          similarity_match?(artist_name, tidal_artist_name)
        else
          tidal_artist_name.downcase.include?(artist_name.downcase) ||
          artist_name.downcase.include?(tidal_artist_name.downcase)
        end
      end
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    else
      nil
    end
  end

  def similarity_match?(str1, str2)
    s1 = str1.downcase.strip
    s2 = str2.downcase.strip

    return true if s1 == s2
    return true if s1.include?(s2) || s2.include?(s1)

    # Remove common punctuation and compare
    s1_clean = s1.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
    s2_clean = s2.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
    return true if s1_clean == s2_clean
    return true if s1_clean.include?(s2_clean) || s2_clean.include?(s1_clean)

    # Try removing articles (the, a, an) and comparing
    s1_no_articles = s1_clean.gsub(/\b(the|a|an)\b/, "").gsub(/\s+/, " ").strip
    s2_no_articles = s2_clean.gsub(/\b(the|a|an)\b/, "").gsub(/\s+/, " ").strip
    return true if s1_no_articles == s2_no_articles

    # Allow small differences based on string length
    min_length = [ s1.length, s2.length ].min
    max_distance = case min_length
    when 0..10 then 1
    when 11..20 then 2
    else 3
    end

    levenshtein_distance(s1, s2) <= max_distance
  end

  def levenshtein_distance(s1, s2)
    return s2.length if s1.empty?
    return s1.length if s2.empty?

    matrix = Array.new(s1.length + 1) { Array.new(s2.length + 1) }

    (0..s1.length).each { |i| matrix[i][0] = i }
    (0..s2.length).each { |j| matrix[0][j] = j }

    (1..s1.length).each do |i|
      (1..s2.length).each do |j|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].min
      end
    end

    matrix[s1.length][s2.length]
  end

  def perform_search_artist_only(track_name, artist_name, token)
    encoded_query = URI.encode_www_form_component(artist_name)

    # Note: Searching for artist, but we want their tracks.
    # Tidal searchResults for artist returns artists, not tracks directly.
    # So we search for the artist name in the 'tracks' scope effectively by just searching generally or using the same endpoint
    # The endpoint searchResults/{query}/relationships/tracks searches for tracks matching the query.
    # If we query the artist name, it should return tracks by that artist.

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 100
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    # Client-side filtering for track name match
    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      title = full_track["attributes"]["title"]
      title.downcase == track_name.downcase || title.downcase.include?(track_name.downcase)
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    else
      nil
    end
  end

  def process_search_response(resp, track_name, artist_name)
    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      relationships = full_track.dig("relationships", "artists", "data") || []
      relationships.any? do |rel|
        artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
        artist && (
          artist["attributes"]["name"].downcase.include?(artist_name.downcase) ||
          artist_name.downcase.include?(artist["attributes"]["name"].downcase)
        )
      end
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    end
  end

  def process_search_response_swap_mode(resp, original_track_name, original_artist_name)
    # In swap mode, we searched for "artist track", so we need different matching logic
    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      track_title = full_track.dig("attributes", "title")
      next unless track_title

      # Check if the track title matches what we're looking for
      title_match = track_title.downcase.include?(original_track_name.downcase) ||
                    original_track_name.downcase.include?(track_title.downcase)

      if title_match
        # Also verify artist match
        relationships = full_track.dig("relationships", "artists", "data") || []
        artist_match = relationships.any? do |rel|
          artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
          artist && (
            artist["attributes"]["name"].downcase.include?(original_artist_name.downcase) ||
            original_artist_name.downcase.include?(artist["attributes"]["name"].downcase)
          )
        end
        artist_match
      else
        false
      end
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    end
  end

  def perform_search_album_artist(track_name, album_name, artist_name, token)
    # Search for album + artist combination
    query = "#{album_name} #{artist_name}".strip
    encoded_query = URI.encode_www_form_component(query)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 50
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    # Find track by name within these results
    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      title = full_track["attributes"]["title"]
      similarity_match?(title, track_name)
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    else
      nil
    end
  end

  def extract_track_details(full_track, included)
    return nil unless full_track

    attributes = full_track["attributes"]
    attributes["id"] = full_track["id"]
    # Add artists from relationships
    relationships = full_track.dig("relationships", "artists", "data") || []
    artists = relationships.map do |rel|
      artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
      artist ? artist["attributes"]["name"] : nil
    end.compact
    attributes["artists"] = artists
    attributes
  end

  def get_tracks(track_ids)
    track_ids.map { |id| get_track(id) }.compact
  end

  def get_track(track_id)
    token = fetch_access_token
    return nil unless token

    resp = Faraday.get("#{TIDAL_API_BASE}/tracks/#{track_id}", {
      countryCode: "US",
      include: "artists"
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })


    return nil unless resp.success?

    json = JSON.parse(resp.body)
    attributes = json.dig("data", "attributes")
    if attributes
      # Fetch artists from relationships link
      artists_link = json.dig("data", "relationships", "artists", "links", "self")
      if artists_link
        artists_resp = Faraday.get("#{TIDAL_API_BASE}#{artists_link}&include=artists", {}, {
          "Authorization" => "Bearer #{token}",
          "accept" => "application/vnd/api+json"
        })
        if artists_resp.success?
          artists_json = JSON.parse(artists_resp.body)
          artist_ids = artists_json.dig("data")&.map { |a| a["id"] } || []
          artists = artist_ids.map do |id|
            artist_resp = Faraday.get("#{TIDAL_API_BASE}/artists/#{id}", {
              countryCode: "US"
            }, {
              "Authorization" => "Bearer #{token}",
              "accept" => "application/vnd/api+json"
            })
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
  def create_playlist(name, description = "")
    token = fetch_access_token
    return nil unless token

    # Correct V2 endpoint from API docs: POST /playlists
    url = "#{TIDAL_API_BASE}/playlists?countryCode=US"
    body = {
      data: {
        attributes: {
          accessType: "PUBLIC",
          description: description,
          name: name
        },
        type: "playlists"
      }
    }

    Rails.logger.info("TidalService: Creating playlist. URL: #{url}, Body: #{body.to_json}")

    resp = Faraday.post(url) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Content-Type"] = "application/vnd.api+json"
      req.headers["Accept"] = "application/vnd.api+json"
      req.body = JSON.generate(body)
    end

    if resp.success?
      result = JSON.parse(resp.body)
      Rails.logger.info("TidalService: Successfully created playlist '#{name}'. Response: #{resp.body}")
      # JSON:API format returns data.id
      result.dig("data")
    else
      Rails.logger.error("TidalService: Failed to create playlist '#{name}'. Status: #{resp.status}, Body: #{resp.body}, Headers: #{resp.headers.to_h}")
      nil
    end
  end

  def add_tracks_to_playlist(playlist_id, track_ids)
    token = fetch_access_token
    return false unless token

    # Tidal API limit: max 20 tracks per request
    # Batch the tracks into groups of 20
    track_ids.each_slice(20).with_index do |batch, index|
      data = batch.map { |track_id| { id: track_id, type: "tracks" } }

      resp = Faraday.post("#{TIDAL_API_BASE}/playlists/#{playlist_id}/relationships/items?countryCode=US") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"] = "application/vnd.api+json"
        req.headers["Accept"] = "application/vnd.api+json"
        req.body = JSON.generate({ data: data })
      end

      unless resp.success?
        Rails.logger.error("TidalService: Failed to add batch #{index + 1} (#{batch.count} tracks) to playlist #{playlist_id}. Status: #{resp.status}, Body: #{resp.body}")
        return false
      end

      Rails.logger.info("TidalService: Added batch #{index + 1} (#{batch.count} tracks) to playlist #{playlist_id}")

      # Small delay between batches to avoid rate limiting
      sleep(0.5) if track_ids.size > 20 && index < (track_ids.size / 20.0).ceil - 1
    end

    Rails.logger.info("TidalService: Successfully added all #{track_ids.count} tracks to playlist #{playlist_id}")
    true
  end

  def fetch_user_id(token)
    v1_base = "https://api.tidal.com/v1"
    resp = Faraday.get("#{v1_base}/users/me") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end

    unless resp.success?
      Rails.logger.error("TidalService: Failed to fetch user_id from V1 API. Status: #{resp.status}, Body: #{resp.body}")
      return nil
    end

    JSON.parse(resp.body)["id"]
  end

  private

  def fetch_access_token
    if @user
      return @user.tidal_access_token unless @user.tidal_token_expired?
      Rails.logger.info("TidalService: Token expired, refreshing...")
      refresh_user_token
    else
      # Client credentials flow (fallback or for non-user actions)
      return nil unless @client_id && @client_secret

      resp = Faraday.post(TIDAL_TOKEN_URL) do |req|
        req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
        req.body = URI.encode_www_form(grant_type: "client_credentials")
      end

      return nil unless resp.success?
      JSON.parse(resp.body)["access_token"]
    end
  end

  def refresh_user_token
    return nil unless @user.tidal_refresh_token

    resp = Faraday.post(TIDAL_TOKEN_URL) do |req|
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      req.body = URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: @user.tidal_refresh_token
      )
    end

    return nil unless resp.success?

    tokens = JSON.parse(resp.body)
    @user.update!(
      tidal_access_token: tokens["access_token"],
      tidal_expires_at: Time.current + tokens["expires_in"].to_i.seconds
    )
    tokens["access_token"]
  end

  def perform_search_album(track_name, album_name, token)
    # Search for the album
    encoded_query = URI.encode_www_form_component(album_name)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/albums", {
      countryCode: "US",
      include: "albums",
      limit: 10
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    albums = json.dig("data") || []

    # Find the best matching album
    matching_album = albums.first
    return nil unless matching_album

    album_id = matching_album["id"]

    # Get tracks from the album
    tracks_resp = Faraday.get("#{TIDAL_API_BASE}/albums/#{album_id}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 100
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless tracks_resp.success?

    tracks_json = JSON.parse(tracks_resp.body)
    tracks = tracks_json.dig("data") || []
    included = tracks_json.dig("included") || []

    # Find track by name
    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      title = full_track["attributes"]["title"]
      title.downcase == track_name.downcase ||
      title.downcase.include?(track_name.downcase) ||
      track_name.downcase.include?(title.downcase)
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    else
      nil
    end
  end

  def perform_search_relaxed(track_name, artist_name, token)
    # Last resort: search for track name only but try to find best match
    # using multiple criteria including artist similarity, track title similarity
    encoded_query = URI.encode_www_form_component(track_name)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 50
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    # Score each track and pick the best one
    scored_tracks = tracks.map do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      track_title = full_track.dig("attributes", "title")
      next unless track_title

      # Calculate title similarity score
      title_score = calculate_title_similarity(track_name, track_title)

      # Calculate artist similarity score
      relationships = full_track.dig("relationships", "artists", "data") || []
      artist_score = relationships.map do |rel|
        artist = included.find { |i| i["id"] == rel["id"] && i["type"] == "artists" }
        if artist
          calculate_artist_similarity(artist_name, artist["attributes"]["name"])
        else
          0
        end
      end.max || 0

      # Combined score (weighted)
      combined_score = (title_score * 0.7) + (artist_score * 0.3)

      {
        track: full_track,
        score: combined_score,
        title_score: title_score,
        artist_score: artist_score
      }
    end.compact

    # Sort by score and take the best match if it's good enough
    best_match = scored_tracks.max_by { |t| t[:score] }

    if best_match && best_match[:score] > 0.5 # Minimum threshold
      extract_track_details(best_match[:track], included)
    else
      nil
    end
  end

  def calculate_title_similarity(title1, title2)
    s1 = title1.downcase.strip
    s2 = title2.downcase.strip

    # Exact match gets highest score
    return 1.0 if s1 == s2

    # Substring match gets high score
    return 0.9 if s1.include?(s2) || s2.include?(s1)

    # Clean and compare (remove punctuation)
    s1_clean = s1.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
    s2_clean = s2.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
    return 0.8 if s1_clean == s2_clean

    # Use Levenshtein distance for fuzzy matching
    max_len = [ s1.length, s2.length ].max
    distance = levenshtein_distance(s1, s2)
    similarity = 1.0 - (distance.to_f / max_len)

    # Apply threshold - titles should be fairly similar
    similarity > 0.6 ? similarity : 0
  end

  def calculate_artist_similarity(artist1, artist2)
    s1 = artist1.downcase.strip
    s2 = artist2.downcase.strip

    # Exact match
    return 1.0 if s1 == s2

    # One contains the other (handles "Artist" vs "Artist feat. Someone")
    return 0.9 if s1.include?(s2) || s2.include?(s1)

    # Check if one is a subset after removing common words
    words1 = s1.split(/\s+/)
    words2 = s2.split(/\s+/)
    common_words = words1 & words2
    return 0.8 if common_words.length > 0 && common_words.length >= [ words1.length, words2.length ].min * 0.5

    # Fuzzy matching for artists - more lenient than titles
    max_len = [ s1.length, s2.length ].max
    distance = levenshtein_distance(s1, s2)
    similarity = 1.0 - (distance.to_f / max_len)

    # More lenient threshold for artists
    similarity > 0.4 ? similarity : 0
  end

  def perform_search_isrc(isrc, token)
    # Search Tidal by ISRC code
    # Note: Tidal's API might not support direct ISRC search in all regions
    # We'll try searching and filtering by ISRC in the results

    encoded_query = URI.encode_www_form_component(isrc)

    resp = Faraday.get("#{TIDAL_API_BASE}/searchResults/#{encoded_query}/relationships/tracks", {
      countryCode: "US",
      include: "tracks,tracks.artists",
      limit: 10
    }, {
      "Authorization" => "Bearer #{token}",
      "accept" => "application/vnd.api+json"
    })

    return nil unless resp.success?

    json = JSON.parse(resp.body)
    tracks = json.dig("data") || []
    included = json.dig("included") || []

    # Look for exact ISRC match in track attributes
    matching_track = tracks.find do |track|
      track_id = track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      next unless full_track

      track_isrc = full_track.dig("attributes", "isrc")
      track_isrc && track_isrc.upcase == isrc.upcase
    end

    if matching_track
      track_id = matching_track["id"]
      full_track = included.find { |t| t["id"] == track_id && t["type"] == "tracks" }
      extract_track_details(full_track, included)
    else
      nil
    end
  end
end
