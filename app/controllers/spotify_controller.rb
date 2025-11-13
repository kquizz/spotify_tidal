class SpotifyController < ApplicationController
  def index
    service = SpotifyService.new
    @playlists = service.playlists
  end
end
