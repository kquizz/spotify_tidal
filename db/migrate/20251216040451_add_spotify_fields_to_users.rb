class AddSpotifyFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :spotify_access_token, :string
    add_column :users, :spotify_refresh_token, :string
    add_column :users, :spotify_expires_at, :datetime
  end
end
