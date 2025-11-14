class AlbumsController < ApplicationController
  def index
    @albums = Album.all
  end

  def show
    @album = Album.find(params[:id])
  end

  def create
    # This will be for saving from Spotify
  end

  def destroy
    @album = Album.find(params[:id])
    @album.destroy
    redirect_to albums_path, notice: "Album deleted successfully."
  end
end
