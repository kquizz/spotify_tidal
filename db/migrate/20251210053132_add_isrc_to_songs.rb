class AddIsrcToSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :songs, :isrc, :string
  end
end
