# frozen_string_literal: true

# TidalService - Official Tidal API Integration
# Documentation: https://developer.tidal.com/documentation/api/api-overview
class TidalService
  include ApiErrorHandler

  AUTH_URL = "https://auth.tidal.com/v1/oauth2"
  API_BASE = "https://openapi.tidal.com"

  def initialize(user: nil, client_id: ENV["TIDAL_CLIENT_ID"], client_secret: ENV["TIDAL_CLIENT_SECRET"])
    @user = user
    @client_id = client_id
    @client_secret = client_secret
    @conn = build_faraday_connection(API_BASE, timeout: 30)
  end

  # OAuth 2.0 - Exchange authorization code for tokens
  def exchange_code_for_token(code, redirect_uri, code_verifier)
    with_retry(context: "Tidal token exchange") do
      resp = Faraday.post("#{AUTH_URL}/token") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          client_id: @client_id,
          client_secret: @client_secret,
          code_verifier: code_verifier
        )
      end

      return nil unless resp.success?
      JSON.parse(resp.body)
    end
  rescue => e
    Rails.logger.error("Tidal token exchange failed: #{e.message}")
    nil
  end

  # Search for a track by name and artist
  # Returns the best matching track or nil
  def search_track(track_name, artist_name, limit: 10, search_log: nil, album_name: nil, isrc: nil)
    token = fetch_access_token
    return nil unless token

    with_rate_limit(service: :tidal) do
      # Try ISRC first if available (most accurate)
      if isrc.present?
        result = search_by_isrc(isrc, token)
        if result
          log_search_result(search_log, "isrc", isrc, "match")
          return format_track_response(result)
        end
        log_search_result(search_log, "isrc", isrc, "no_match")
      end

      # Try album-based lookup if album name is available (very accurate)
      if album_name.present?
        Rails.logger.info("TidalService: Trying album-based lookup for '#{track_name}' on '#{album_name}'")
        log_search_result(search_log, "album_lookup", "#{album_name} by #{artist_name}", nil)

        result = search_track_via_album(track_name, artist_name, album_name, token)
        if result
          Rails.logger.info("TidalService: Album lookup match found - #{result['title']}")
          log_search_result(search_log, "album_lookup", "#{album_name} by #{artist_name}", "match")
          return format_track_response(result)
        end
        log_search_result(search_log, "album_lookup", "#{album_name} by #{artist_name}", "no_match")
      end

      # Try different search strategies
      strategies = build_search_strategies(track_name, artist_name, album_name)

      strategies.each_with_index do |strategy, index|
        query = strategy[:query]
        next if query.blank?

        Rails.logger.info("TidalService: Strategy #{index} (#{strategy[:type]}) - Searching: '#{query}'")
        log_search_result(search_log, strategy[:type], query, nil)

        results = perform_search(query, token, limit: 20)
        next unless results

        # Find best match from results
        match = find_best_match(results, track_name, artist_name, album_name)
        if match
          Rails.logger.info("TidalService: Match found - #{match['title']} by #{format_artists(match)}")
          log_search_result(search_log, strategy[:type], query, "match")
          return format_track_response(match)
        end

        log_search_result(search_log, strategy[:type], query, "no_match")
      end

      Rails.logger.warn("TidalService: No match found for '#{track_name}' by '#{artist_name}'")
      nil
    end
  rescue => e
    Rails.logger.error("TidalService search error: #{e.message}")
    nil
  end

  # Create a new playlist
  def create_playlist(name, description = "")
    token = fetch_access_token
    return nil unless token

    with_rate_limit(service: :tidal) do
      user_id = get_user_id(token)
      return nil unless user_id

      resp = @conn.post("/v2/playlists") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"] = "application/vnd.api+json"
        req.body = {
          data: {
            type: "playlists",
            attributes: {
              title: name,
              description: description,
              public: false
            }
          }
        }.to_json
      end

      return nil unless resp.success?
      JSON.parse(resp.body).dig("data")
    end
  rescue => e
    Rails.logger.error("Failed to create Tidal playlist: #{e.message}")
    nil
  end

  # Add tracks to a playlist
  def add_tracks_to_playlist(playlist_uuid, track_ids)
    return false if track_ids.empty?

    token = fetch_access_token
    return false unless token

    with_rate_limit(service: :tidal) do
      # Tidal API accepts batches - let's do 100 at a time
      track_ids.each_slice(100) do |batch|
        # Format track IDs as resource identifiers
        items = batch.map do |track_id|
          {
            type: "tracks",
            id: track_id.to_s
          }
        end

        resp = @conn.post("/v2/playlists/#{playlist_uuid}/items") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Content-Type"] = "application/vnd.api+json"
          req.body = {
            data: items
          }.to_json
        end

        unless resp.success?
          Rails.logger.error("Failed to add tracks to playlist: #{resp.status}")
          return false
        end
      end

      true
    end
  rescue => e
    Rails.logger.error("Failed to add tracks to Tidal playlist: #{e.message}")
    false
  end

  private

  # Fetch access token (user token or client credentials)
  def fetch_access_token
    if @user
      return @user.tidal_access_token unless @user.tidal_token_expired?
      Rails.logger.info("TidalService: Token expired, refreshing...")
      refresh_user_token
    else
      # Client credentials flow for non-user operations
      get_client_credentials_token
    end
  end

  # Refresh user's access token
  def refresh_user_token
    return nil unless @user&.tidal_refresh_token

    resp = Faraday.post("#{AUTH_URL}/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: @user.tidal_refresh_token,
        client_id: @client_id,
        client_secret: @client_secret
      )
    end

    return nil unless resp.success?

    tokens = JSON.parse(resp.body)
    @user.update!(
      tidal_access_token: tokens["access_token"],
      tidal_refresh_token: tokens["refresh_token"] || @user.tidal_refresh_token,
      tidal_expires_at: Time.current + tokens["expires_in"].to_i.seconds
    )
    tokens["access_token"]
  rescue => e
    Rails.logger.error("Failed to refresh Tidal token: #{e.message}")
    nil
  end

  # Get client credentials token (for searches without user)
  def get_client_credentials_token
    return nil unless @client_id && @client_secret

    resp = Faraday.post("#{AUTH_URL}/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret
      )
    end

    return nil unless resp.success?
    JSON.parse(resp.body)["access_token"]
  rescue => e
    Rails.logger.error("Failed to get Tidal client credentials: #{e.message}")
    nil
  end

  # Get current user's ID
  def get_user_id(token)
    resp = @conn.get("/v2/me") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end

    return nil unless resp.success?
    JSON.parse(resp.body).dig("data", "id")
  rescue => e
    Rails.logger.error("Failed to get Tidal user ID: #{e.message}")
    nil
  end

  # Search by ISRC (International Standard Recording Code)
  def search_by_isrc(isrc, token)
    Rails.logger.info("TidalService: Searching by ISRC '#{isrc}'")

    # Tidal API v2 catalog search
    resp = @conn.get("/v2/tracks") do |req|
      req.params["filter[isrc]"] = isrc
      req.params["countryCode"] = "US"
      req.headers["Authorization"] = "Bearer #{token}"
    end

    return nil unless resp.success?

    data = JSON.parse(resp.body)
    tracks = data.dig("data")
    return nil if tracks.nil? || tracks.empty?

    tracks.first
  rescue => e
    Rails.logger.error("ISRC search failed: #{e.message}")
    nil
  end

  # Search for track by finding the album first, then matching track within album
  def search_track_via_album(track_name, artist_name, album_name, token)
    # Step 1: Search for the album
    albums = search_albums("#{album_name} #{artist_name}", token, limit: 10)
    return nil if albums.nil? || albums.empty?

    # Step 2: Find best matching album
    best_album = find_best_album_match(albums, album_name, artist_name)
    return nil unless best_album

    album_id = best_album["id"]
    Rails.logger.info("TidalService: Found album '#{best_album.dig('attributes', 'title')}' (ID: #{album_id})")

    # Step 3: Get tracks from this album
    album_tracks = get_album_tracks(album_id, token)
    return nil if album_tracks.nil? || album_tracks.empty?

    Rails.logger.info("TidalService: Album has #{album_tracks.length} tracks, searching for '#{track_name}'")

    # Step 4: Find matching track in the album
    find_track_in_album(album_tracks, track_name)
  rescue => e
    Rails.logger.error("Album-based search failed: #{e.message}")
    nil
  end

  # Search for albums
  def search_albums(query, token, limit: 10)
    resp = @conn.get("/v2/searchresults/catalog") do |req|
      req.params["query"] = query
      req.params["type"] = "albums"
      req.params["limit"] = limit
      req.params["countryCode"] = "US"
      req.headers["Authorization"] = "Bearer #{token}"
    end

    return nil unless resp.success?

    data = JSON.parse(resp.body)
    data.dig("data", "albums") || []
  rescue => e
    Rails.logger.error("Album search failed: #{e.message}")
    nil
  end

  # Find best matching album from search results
  def find_best_album_match(albums, album_name, artist_name)
    return nil if albums.empty?

    scored_albums = albums.map do |album|
      album_title = album.dig("attributes", "title") || ""
      album_artists = album.dig("relationships", "artists", "data")&.map { |a| a.dig("attributes", "name") }&.join(", ") || ""

      title_score = best_string_similarity(
        normalize_for_matching(album_name),
        normalize_for_matching(album_title)
      )
      artist_score = best_string_similarity(
        normalize_for_matching(artist_name),
        normalize_for_matching(album_artists)
      )

      # Weight album title match more heavily
      score = (title_score * 0.7) + (artist_score * 0.3)
      { album: album, score: score }
    end

    best = scored_albums.max_by { |r| r[:score] }
    best[:score] >= 0.6 ? best[:album] : nil
  end

  # Get all tracks from an album
  def get_album_tracks(album_id, token)
    resp = @conn.get("/v2/albums/#{album_id}/items") do |req|
      req.params["countryCode"] = "US"
      req.params["limit"] = 100
      req.headers["Authorization"] = "Bearer #{token}"
    end

    return nil unless resp.success?

    data = JSON.parse(resp.body)
    data.dig("data") || []
  rescue => e
    Rails.logger.error("Failed to get album tracks: #{e.message}")
    nil
  end

  # Find a track within album tracks by name
  def find_track_in_album(album_tracks, track_name)
    normalized_search = normalize_for_matching(track_name)
    clean_search = normalize_for_matching(clean_string(track_name))

    scored_tracks = album_tracks.map do |track|
      track_title = track.dig("attributes", "title") || ""
      normalized_title = normalize_for_matching(track_title)

      # Try multiple comparison methods
      exact_score = string_similarity(normalized_search, normalized_title)
      clean_score = string_similarity(clean_search, normalized_title)
      contains_score = normalized_title.include?(normalized_search) || normalized_search.include?(normalized_title) ? 0.85 : 0

      score = [ exact_score, clean_score, contains_score ].max
      { track: track, score: score }
    end

    best = scored_tracks.max_by { |r| r[:score] }

    if best[:score] >= 0.7
      Rails.logger.info("TidalService: Found track in album with score #{best[:score].round(3)}: '#{best[:track].dig('attributes', 'title')}'")
      best[:track]
    else
      Rails.logger.debug("TidalService: Best album track match was only #{best[:score].round(3)}")
      nil
    end
  end

  # Perform a general search query
  def perform_search(query, token, limit: 20)
    resp = @conn.get("/v2/searchresults/catalog") do |req|
      req.params["query"] = query
      req.params["type"] = "tracks"
      req.params["limit"] = limit
      req.params["countryCode"] = "US"
      req.headers["Authorization"] = "Bearer #{token}"
    end

    return nil unless resp.success?

    data = JSON.parse(resp.body)
    data.dig("data", "tracks") || []
  rescue => e
    Rails.logger.error("Tidal search failed: #{e.message}")
    nil
  end

  # Build search strategy queries - comprehensive approach to maximize matches
  def build_search_strategies(track_name, artist_name, album_name)
    strategies = []

    # Strategy 1: Exact "track artist" search
    strategies << { type: "exact", query: "#{track_name} #{artist_name}".strip }

    # Strategy 2: Artist first, then track (sometimes works better)
    strategies << { type: "artist_first", query: "#{artist_name} #{track_name}".strip }

    # Strategy 3: Include album if available
    if album_name.present?
      strategies << { type: "with_album", query: "#{track_name} #{album_name}".strip }
      strategies << { type: "artist_album", query: "#{artist_name} #{album_name}".strip }
    end

    # Strategy 4: Clean strings (remove feat, remastered, remix indicators, etc)
    clean_track = clean_string(track_name)
    clean_artist = clean_artist_name(artist_name)
    if clean_track != track_name || clean_artist != artist_name
      strategies << { type: "cleaned", query: "#{clean_track} #{clean_artist}".strip }
    end

    # Strategy 5: Remove remix/version indicators
    no_remix_track = remove_version_indicators(track_name)
    if no_remix_track != track_name && no_remix_track != clean_track
      strategies << { type: "no_remix", query: "#{no_remix_track} #{clean_artist}".strip }
    end

    # Strategy 6: Primary artist only (first name before "feat", "&", etc)
    primary_artist = extract_primary_artist(artist_name)
    if primary_artist && primary_artist != artist_name && primary_artist != clean_artist
      strategies << { type: "primary_artist", query: "#{track_name} #{primary_artist}".strip }
      strategies << { type: "primary_artist_clean", query: "#{clean_track} #{primary_artist}".strip }
    end

    # Strategy 7: Track name only (broad search, rely on matching)
    strategies << { type: "track_only", query: track_name }
    if clean_track != track_name
      strategies << { type: "track_only_clean", query: clean_track }
    end

    # Strategy 8: Handle "The" prefix variations
    if artist_name.downcase.start_with?("the ")
      without_the = artist_name[4..]
      strategies << { type: "without_the", query: "#{track_name} #{without_the}".strip }
    elsif !artist_name.downcase.start_with?("the ")
      with_the = "The #{artist_name}"
      strategies << { type: "with_the", query: "#{track_name} #{with_the}".strip }
    end

    # Strategy 9: Unicode/special character normalization
    normalized_track = normalize_unicode(track_name)
    normalized_artist = normalize_unicode(artist_name)
    if normalized_track != track_name || normalized_artist != artist_name
      strategies << { type: "unicode_normalized", query: "#{normalized_track} #{normalized_artist}".strip }
    end

    # Strategy 10: Handle featuring artists as separate search
    featured_artists = extract_featured_artists(artist_name)
    featured_artists.each do |featured|
      strategies << { type: "featured_artist", query: "#{track_name} #{featured}".strip }
    end

    # Strategy 11: Simplified track name (first part before dash or parenthesis)
    simplified_track = simplify_track_name(track_name)
    if simplified_track != track_name && simplified_track != clean_track
      strategies << { type: "simplified", query: "#{simplified_track} #{artist_name}".strip }
    end

    # Strategy 12: Words only (remove all special chars for fuzzy matching)
    words_only_track = extract_words_only(track_name)
    words_only_artist = extract_words_only(artist_name)
    if words_only_track.length >= 3
      strategies << { type: "words_only", query: "#{words_only_track} #{words_only_artist}".strip }
    end

    # Remove duplicate queries while preserving strategy types
    seen_queries = Set.new
    strategies.reject! do |s|
      normalized = s[:query].downcase.gsub(/\s+/, " ").strip
      if seen_queries.include?(normalized)
        true
      else
        seen_queries.add(normalized)
        false
      end
    end

    strategies
  end

  # Find best matching track from search results
  def find_best_match(results, track_name, artist_name, album_name)
    return nil if results.nil? || results.empty?

    # Score each result and pick the best
    scored_results = results.map do |track|
      score = calculate_match_score(track, track_name, artist_name, album_name)
      { track: track, score: score }
    end

    # Sort by score descending
    scored_results.sort_by! { |r| -r[:score] }

    # Log top matches for debugging
    if scored_results.any?
      top = scored_results.first
      Rails.logger.debug("TidalService: Best match score #{top[:score].round(3)} for '#{top[:track].dig('attributes', 'title')}'")
    end

    # Accept matches above threshold (lowered for better recall)
    best = scored_results.first
    best[:score] >= 0.5 ? best[:track] : nil
  end

  # Calculate match score (0.0 to 1.0)
  def calculate_match_score(track, track_name, artist_name, album_name)
    track_title = track.dig("attributes", "title") || ""
    track_artists = format_artists(track)
    track_album = track.dig("relationships", "album", "data", "attributes", "title") || ""

    # Normalize all strings for comparison
    norm_search_title = normalize_for_matching(track_name)
    norm_search_artist = normalize_for_matching(artist_name)
    norm_track_title = normalize_for_matching(track_title)
    norm_track_artist = normalize_for_matching(track_artists)

    # Calculate title similarity (most important)
    title_score = best_string_similarity(norm_search_title, norm_track_title)

    # Calculate artist similarity
    artist_score = best_string_similarity(norm_search_artist, norm_track_artist)

    # Check if any search artist appears in track artists (handles multi-artist tracks)
    artist_contains_bonus = 0
    search_artists = extract_all_artists(artist_name)
    track_artist_list = extract_all_artists(track_artists)

    search_artists.each do |sa|
      track_artist_list.each do |ta|
        if string_similarity(normalize_for_matching(sa), normalize_for_matching(ta)) > 0.85
          artist_contains_bonus = 0.15
          break
        end
      end
      break if artist_contains_bonus > 0
    end

    # Weighted score
    score = (title_score * 0.6) + (artist_score * 0.3) + artist_contains_bonus

    # Bonus if album matches
    if album_name.present? && track_album.present?
      norm_search_album = normalize_for_matching(album_name)
      norm_track_album = normalize_for_matching(track_album)
      album_score = string_similarity(norm_search_album, norm_track_album)
      score += (album_score * 0.1) if album_score > 0.7
    end

    # Exact title match bonus
    if norm_search_title == norm_track_title
      score = [ score + 0.15, 1.0 ].min
    end

    score
  end

  # Best string similarity - tries multiple comparison methods
  def best_string_similarity(s1, s2)
    return 1.0 if s1 == s2
    return 0.0 if s1.empty? || s2.empty?

    # Standard Levenshtein similarity
    lev_score = string_similarity(s1, s2)

    # Check if one contains the other (substring match)
    contains_score = 0.0
    if s1.include?(s2) || s2.include?(s1)
      shorter = [ s1.length, s2.length ].min
      longer = [ s1.length, s2.length ].max
      contains_score = shorter.to_f / longer * 0.9
    end

    # Word overlap score
    words1 = s1.split(/\s+/).to_set
    words2 = s2.split(/\s+/).to_set
    if words1.any? && words2.any?
      intersection = words1 & words2
      union = words1 | words2
      word_score = intersection.size.to_f / union.size
    else
      word_score = 0.0
    end

    # Return best score
    [ lev_score, contains_score, word_score ].max
  end

  # Levenshtein distance implementation
  def levenshtein_distance(s1, s2)
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

  # Normalize string for comparison
  def normalize_string(str)
    str.to_s.downcase.strip
      .gsub(/[^\w\s]/, "")  # Remove punctuation
      .gsub(/\s+/, " ")     # Normalize whitespace
  end

  # Normalize for matching - more aggressive normalization
  def normalize_for_matching(str)
    str.to_s.downcase.strip
      .gsub(/[''`]/, "")     # Remove apostrophes
      .gsub(/[^\w\s]/, " ")  # Replace punctuation with space
      .gsub(/\s+/, " ")      # Normalize whitespace
      .strip
  end

  # Clean string (remove extra info)
  def clean_string(str)
    str.gsub(/\s*[\(\[].*?[\)\]]\s*/, "")  # Remove content in parentheses/brackets
      .gsub(/\s*-\s*(remaster|deluxe|extended|bonus|anniversary|edition).*$/i, "")
      .gsub(/\s*\d{4}\s*(remaster|version).*$/i, "")  # Remove "2023 Remaster" etc
      .strip
  end

  # Remove version/remix indicators
  def remove_version_indicators(str)
    str.gsub(/\s*[\(\[].*?(remix|mix|edit|version|radio|extended|instrumental|acoustic|live|demo).*?[\)\]]\s*/i, "")
      .gsub(/\s*-\s*(remix|mix|edit|version|radio|extended|instrumental|acoustic|live|demo).*$/i, "")
      .strip
  end

  # Clean artist name (remove featuring artists)
  def clean_artist_name(str)
    str.split(/\s+(?:feat\.?|ft\.?|featuring|with|vs\.?|versus|x)\s+/i).first&.strip || str
  end

  # Extract primary artist (handles multiple separators)
  def extract_primary_artist(str)
    # Split on common artist separators
    str.split(/\s*(?:feat\.?|ft\.?|featuring|with|&|,|and|vs\.?|versus|x|\+)\s*/i).first&.strip
  end

  # Extract all artists from a string
  def extract_all_artists(str)
    str.split(/\s*(?:feat\.?|ft\.?|featuring|with|&|,|and|vs\.?|versus|x|\+)\s*/i)
      .map(&:strip)
      .reject(&:empty?)
  end

  # Extract featured artists only
  def extract_featured_artists(str)
    # Match text after featuring keywords
    match = str.match(/(?:feat\.?|ft\.?|featuring|with)\s+(.+)$/i)
    return [] unless match

    match[1].split(/\s*(?:&|,|and|\+)\s*/i).map(&:strip).reject(&:empty?)
  end

  # Simplify track name (get core title)
  def simplify_track_name(str)
    # Take first part before common separators
    str.split(/\s*[-–—]\s*/).first&.strip || str
  end

  # Extract only words (letters and numbers)
  def extract_words_only(str)
    str.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
  end

  # Normalize unicode characters
  def normalize_unicode(str)
    # Common unicode character mappings
    str.tr("''""", "''\"\"")
      .gsub(/[àáâãäå]/i, "a")
      .gsub(/[èéêë]/i, "e")
      .gsub(/[ìíîï]/i, "i")
      .gsub(/[òóôõö]/i, "o")
      .gsub(/[ùúûü]/i, "u")
      .gsub(/[ñ]/i, "n")
      .gsub(/[ç]/i, "c")
      .gsub(/æ/i, "ae")
      .gsub(/œ/i, "oe")
      .gsub(/ß/, "ss")
  end

  # Calculate string similarity using Levenshtein algorithm
  def string_similarity(s1, s2)
    return 1.0 if s1 == s2
    return 0.0 if s1.empty? || s2.empty?

    longer = [ s1.length, s2.length ].max
    distance = levenshtein_distance(s1, s2)
    (longer - distance) / longer.to_f
  end

  # Format artists from track data
  def format_artists(track)
    artists = track.dig("relationships", "artists", "data") || []
    artists.map { |a| a.dig("attributes", "name") }.compact.join(", ")
  end

  # Format track response
  def format_track_response(track)
    {
      "id" => track["id"],
      "title" => track.dig("attributes", "title"),
      "artists" => format_artists(track).split(", "),
      "album" => track.dig("relationships", "album", "data", "attributes", "title"),
      "duration" => track.dig("attributes", "duration"),
      "isrc" => track.dig("attributes", "isrc")
    }
  end

  # Log search results
  def log_search_result(search_log, type, query, result)
    return unless search_log

    if result.nil?
      search_log << { strategy: type, query: query }
    else
      search_log.last[:result] = result if search_log.any?
    end
  end
end
