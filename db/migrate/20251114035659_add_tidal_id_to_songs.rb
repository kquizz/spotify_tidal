class AddTidalIdToSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :songs, :tidal_id, :string
  end
end
