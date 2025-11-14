class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.string :name
      t.string :spotify_id
      t.references :artist, null: false, foreign_key: true
      t.string :image_url

      t.timestamps
    end
  end
end
