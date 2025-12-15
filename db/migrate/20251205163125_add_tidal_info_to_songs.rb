class AddTidalInfoToSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :songs, :tidal_track_name, :string
    add_column :songs, :tidal_artist_name, :string
  end
end
