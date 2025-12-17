class AddIndexesToModels < ActiveRecord::Migration[8.1]
  def change
    # Add indexes for frequently queried fields
    add_index :playlists, :spotify_id, unique: true, if_not_exists: true
    add_index :playlists, :tidal_playlist_id, if_not_exists: true
    add_index :playlists, :import_status, if_not_exists: true

    add_index :songs, :spotify_id, unique: true, if_not_exists: true
    add_index :songs, :tidal_id, if_not_exists: true
    add_index :songs, :artist_id, if_not_exists: true
    add_index :songs, :album_id, if_not_exists: true

    add_index :artists, :spotify_id, unique: true, if_not_exists: true
    add_index :artists, :name, if_not_exists: true

    add_index :albums, :spotify_id, unique: true, if_not_exists: true
    add_index :albums, :artist_id, if_not_exists: true

    add_index :playlist_songs, [ :playlist_id, :song_id ], unique: true, if_not_exists: true
  end
end
