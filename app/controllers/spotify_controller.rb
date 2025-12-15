class SpotifyController < ApplicationController
  def index
    @saved_playlist_ids = []
    if params[:user_id].present?
      service = SpotifyService.new
      @searched_playlists = service.user_playlists(params[:user_id])
      @searched_user_id = params[:user_id]
      playlist_ids = @searched_playlists.map { |p| p[:id] }
      @saved_playlist_ids = Playlist.where(spotify_id: playlist_ids).pluck(:spotify_id) if playlist_ids.any?
    end
  end

  def show
    service = SpotifyService.new
    @playlist_tracks = service.playlist_tracks(params[:id])

    respond_to do |format|
      format.html { render layout: false if request.xhr? }
    end
  end



  def sync
    @playlists = Playlist.includes(:songs).all
  end

  def compare
    puts "Compare action called"
    enqueued_count = 0

    Playlist.includes(:songs).find_each do |playlist|
      playlist.songs.each do |song|
        next if song.tidal_id.present?

        TidalLookupJob.perform_later(song.id)
        enqueued_count += 1
      end
    end

    redirect_to sync_path, notice: "Enqueued #{enqueued_count} songs for Tidal lookup"
  end

  def sync_all
    unless Current.user.tidal_connected?
      redirect_to sync_path, alert: "Please connect your Tidal account first."
      return
    end

    # Enqueue background job for Tidal sync
    TidalSyncJob.perform_later(Current.user.id)
    redirect_to sync_path, notice: "Tidal sync started in background! This may take a few minutes..."
  end
end
