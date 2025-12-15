class TidalLookupJob < ApplicationJob
  queue_as :default

  def perform(song_id)
    song = Song.find(song_id)
    return if song.tidal_id.present?

    Rails.logger.info("TidalLookupJob: Looking up song '#{song.name}' by '#{song.artist.name}' (ID: #{song.id})")

    # Clear old lookup logs and start fresh
    search_attempt = {
      timestamp: Time.current.iso8601,
      searched_title: song.name,
      searched_artist: song.artist.name,
      strategies: []
    }

    tidal_service = TidalService.new
    album_name = song.album&.name
    isrc = song.isrc
    tidal_track = tidal_service.search_track(
      song.name,
      song.artist.name,
      search_log: search_attempt[:strategies],
      album_name: album_name,
      isrc: isrc
    )

    if tidal_track && tidal_track["id"]
      Rails.logger.info("TidalLookupJob: Found Tidal track for '#{song.name}' (Tidal ID: #{tidal_track["id"]})")

      # Extract artist name safely
      artist_name = if tidal_track["artists"].is_a?(Array)
        tidal_track["artists"].join(", ")
      else
        tidal_track.dig("artist", "name") || "Unknown Artist"
      end

      search_attempt[:result] = "found"
      search_attempt[:tidal_id] = tidal_track["id"]
      search_attempt[:tidal_title] = tidal_track["title"]
      search_attempt[:tidal_artist] = artist_name

      # Store only the current lookup attempt
      song.update(
        tidal_id: tidal_track["id"],
        tidal_track_name: tidal_track["title"],
        tidal_artist_name: artist_name,
        lookup_log: [ search_attempt ].to_json
      )

      # Broadcast realtime updates
      Turbo::StreamsChannel.broadcast_replace_to(
        "sync_page",
        target: "song_#{song.id}",
        partial: "shared/song_line",
        locals: { song: song }
      )
    else
      Rails.logger.info("TidalLookupJob: No Tidal track found for '#{song.name}' by '#{song.artist.name}'")

      search_attempt[:result] = "not_found"

      # Store only the current lookup attempt
      song.update(lookup_log: [ search_attempt ].to_json)

      # Broadcast update to show "not found" status
      Turbo::StreamsChannel.broadcast_replace_to(
        "sync_page",
        target: "song_#{song.id}",
        partial: "shared/song_line",
        locals: { song: song }
      )
    end
  rescue => e
    # If Tidal is down or any error, log it
    Rails.logger.warn("TidalLookupJob failed for song #{song_id}: #{e.message}")

    error_log = [ {
      timestamp: Time.current.iso8601,
      result: "error",
      error: e.message
    } ]
    song.update(lookup_log: error_log.to_json) rescue nil
  end
end
