class AddTidalPlaylistIdToPlaylists < ActiveRecord::Migration[8.1]
  def change
    add_column :playlists, :tidal_playlist_id, :string
  end
end
