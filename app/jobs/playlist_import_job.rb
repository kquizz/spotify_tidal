class PlaylistImportJob < ApplicationJob
  queue_as :default

  def perform(playlist_id)
    playlist = Playlist.find(playlist_id)
    service = SpotifyService.new(user: Current.user)
    # Mark import as in_progress
    playlist.update(import_status: "in_progress")

    # Fetch all tracks from Spotify
    tracks_data = service.playlist_tracks(playlist.spotify_id)

    if tracks_data.nil?
      msg = "failed to fetch tracks for playlist=#{playlist.id} spotify_id=#{playlist.spotify_id}"
      playlist.update(import_status: "failed", last_import_error: msg)
      Rails.logger.error("PlaylistImportJob: #{msg}") if defined?(Rails)
      return
    end

    begin
      tracks_data.each do |track_data|
      # Find or create artist
      artist = Artist.find_or_create_by!(spotify_id: track_data[:artist_id]) do |a|
        a.name = track_data[:artists]
      end

      # Find or create album
      album = Album.find_or_create_by!(spotify_id: track_data[:album_id]) do |a|
        a.name = track_data[:album]
        a.artist = artist
        a.image_url = track_data[:album_image]
      end

      # Find or create song
      song = Song.find_or_create_by!(spotify_id: track_data[:id]) do |s|
        s.name = track_data[:name]
        s.artist = artist
        s.album = album
        s.isrc = track_data[:isrc]
      end

      # Update ISRC if it was missing
      song.update(isrc: track_data[:isrc]) if track_data[:isrc].present? && song.isrc.blank?

      # Add to playlist if not already there
      unless playlist.songs.include?(song)
        playlist.songs << song
      end
    end

      # Update playlist status
      playlist.update(import_status: "completed", tracks_total: tracks_data.count, last_import_error: nil)
    rescue StandardError => e
      playlist.update(import_status: "failed", last_import_error: "#{e.class}: #{e.message}")
      Rails.logger.error("PlaylistImportJob: exception importing playlist=#{playlist.id} - #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}") if defined?(Rails)
      return
    end

    # Enqueue Tidal lookup for songs without tidal_id
    playlist.songs.where(tidal_id: nil).find_each do |song|
      TidalLookupJob.perform_later(song.id)
    end
  end
end
