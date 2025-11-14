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
end
