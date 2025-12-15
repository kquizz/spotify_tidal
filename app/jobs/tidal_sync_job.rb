class TidalSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id, playlist_ids = nil)
    user = User.find(user_id)
    service = TidalService.new(user: user)
    
    playlists = playlist_ids ? Playlist.where(id: playlist_ids) : Playlist.all
    success_count = 0
    fail_count = 0
    
    playlists.each do |playlist|
      # Skip if already synced
      if playlist.tidal_playlist_id.present?
        Rails.logger.info("Playlist '#{playlist.name}' already synced, skipping...")
        success_count += 1
        next
      end
      
      # Create playlist on Tidal
      tidal_playlist = service.create_playlist(playlist.name, "Synced from Spotify")
      
      if tidal_playlist
        playlist.update(tidal_playlist_id: tidal_playlist["id"])
        
        # Add tracks
        tidal_track_ids = playlist.songs.map(&:tidal_id).compact
        
        if tidal_track_ids.any?
          if service.add_tracks_to_playlist(tidal_playlist["id"], tidal_track_ids)
            success_count += 1
          else
            fail_count += 1
          end
        else
          success_count += 1
        end
      else
        fail_count += 1
      end
    end
    
    Rails.logger.info("Tidal sync complete: #{success_count} succeeded, #{fail_count} failed")
  end
end
