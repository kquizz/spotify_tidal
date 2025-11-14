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

  def colors
  end

  def sync
    @playlists = Playlist.includes(:songs).all
  end

  def compare
    puts "Compare action called"
    tidal_service = TidalService.new
    updated_count = 0

    Playlist.includes(:songs).find_each do |playlist|
      playlist.songs.each do |song|
        next if song.tidal_id.present?

        tidal_track = tidal_service.search_track(song.name, song.artist.name)
        if tidal_track && tidal_track["id"]
          song.update(tidal_id: tidal_track["id"])
          updated_count += 1
        end
      end
    end

    redirect_to sync_path, notice: "Compared #{updated_count} songs with Tidal"
  end
end
