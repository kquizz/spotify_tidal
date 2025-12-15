class AddLookupLogToSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :songs, :lookup_log, :text
  end
end
