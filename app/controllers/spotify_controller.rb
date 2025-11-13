class SpotifyController < ApplicationController
  def index
    if params[:user_id].present?
      service = SpotifyService.new
      @searched_playlists = service.user_playlists(params[:user_id])
      @searched_user_id = params[:user_id]
    end
  end
end
