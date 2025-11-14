class PlaylistsController < ApplicationController
  def index
    @playlists = Playlist.all
  end

  def show
    @playlist = Playlist.find(params[:id])
  end

  def create
    @playlist = Playlist.new(playlist_params)
    if @playlist.save
      # Optionally save the tracks
      save_playlist_tracks(@playlist)
      redirect_to playlists_path, notice: "Playlist saved successfully."
    else
      redirect_to root_path, alert: "Failed to save playlist."
    end
  end

  def destroy
    @playlist = Playlist.find(params[:id])
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist deleted successfully."
  end

  private

  def playlist_params
    params.require(:playlist).permit(:name, :spotify_id, :owner, :image_url, :tracks_total)
  end

  def save_playlist_tracks(playlist)
    service = SpotifyService.new
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
