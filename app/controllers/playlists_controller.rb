class PlaylistsController < ApplicationController
  def index
    @playlists = Playlist.all
  end

  def show
    @playlist = Playlist.includes(songs: [:artist, :album]).find(params[:id])
  end

  def create
    @playlist = Playlist.new(playlist_params)
    @playlist.import_status = "pending"

    if @playlist.save
      # Enqueue background job to import tracks
      PlaylistImportJob.perform_later(@playlist.id)
      redirect_to playlists_path, notice: "Playlist saved! Importing tracks in background..."
    else
      redirect_to root_path, alert: "Failed to save playlist."
    end
  end

  def destroy
    @playlist = Playlist.find(params[:id])
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist deleted successfully."
  end

  def sync_to_tidal
    @playlist = Playlist.find(params[:id])

    unless Current.user.tidal_connected?
      redirect_to playlists_path, alert: "Please connect your Tidal account first."
      return
    end

    service = TidalService.new(user: Current.user)

    # Create playlist on Tidal
    tidal_playlist = service.create_playlist(@playlist.name, "Synced from Spotify via SpotifyTidalApp")

    if tidal_playlist
      # Collect Tidal track IDs
      tidal_track_ids = @playlist.songs.map(&:tidal_id).compact

      if tidal_track_ids.any?
        success = service.add_tracks_to_playlist(tidal_playlist["uuid"], tidal_track_ids)
        if success
          redirect_to playlist_path(@playlist), notice: "Playlist synced to Tidal successfully!"
        else
          redirect_to playlist_path(@playlist), alert: "Playlist created but failed to add tracks."
        end
      else
        redirect_to playlist_path(@playlist), notice: "Playlist created on Tidal (no tracks found to sync)."
      end
    else
      redirect_to playlist_path(@playlist), alert: "Failed to create playlist on Tidal."
    end
  end

  def retry_import
    @playlist = Playlist.find(params[:id])

    unless @playlist
      redirect_to playlists_path, alert: "Playlist not found."
      return
    end

    @playlist.update(import_status: "pending")
    PlaylistImportJob.perform_later(@playlist.id)
    redirect_to playlist_path(@playlist), notice: "Re-enqueued playlist import."
  end

  def retry_all_failed_imports
    failed_playlists = Playlist.where(import_status: 'failed')
    failed_playlists.find_each do |pl|
      pl.update(import_status: 'pending')
      PlaylistImportJob.perform_later(pl.id)
    end

    redirect_to sync_path, notice: "Enqueued import for #{failed_playlists.size} failed playlist#{failed_playlists.size == 1 ? '' : 's'}."
  end

  def lookup_tracks
    @playlist = Playlist.find(params[:id])

    # Only lookup songs without a Tidal ID
    songs_to_lookup = @playlist.songs.where(tidal_id: nil)

    songs_to_lookup.each do |song|
      TidalLookupJob.perform_later(song.id)
    end

    if songs_to_lookup.any?
      redirect_to playlist_path(@playlist), notice: "Tidal lookup started for #{songs_to_lookup.count} track#{songs_to_lookup.count == 1 ? '' : 's'}..."
    else
      redirect_to playlist_path(@playlist), notice: "All tracks already have Tidal matches!"
    end
  end

  private

  def playlist_params
    params.require(:playlist).permit(:name, :spotify_id, :owner, :image_url, :tracks_total)
  end

  def save_playlist_tracks(playlist)
    service = SpotifyService.new(user: Current.user)
    tracks = service.playlist_tracks(playlist.spotify_id)
    tracks.each do |track_data|
      artist = Artist.find_or_create_by(spotify_id: track_data[:artist_id]) do |a|
        a.name = track_data[:artists]
      end
      album = Album.find_or_create_by(spotify_id: track_data[:album_id]) do |al|
        al.name = track_data[:album]
        al.artist = artist
        al.image_url = track_data[:album_image]
      end
      song = Song.find_or_create_by(spotify_id: track_data[:id]) do |s|
        s.name = track_data[:name]
        s.artist = artist
        s.album = album
      end
      playlist.songs << song unless playlist.songs.include?(song)
    end
  end
end
