class CreatePlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :playlists do |t|
      t.string :name
      t.string :spotify_id
      t.string :owner
      t.string :image_url
      t.integer :tracks_total

      t.timestamps
    end
  end
end
