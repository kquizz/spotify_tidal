class AddImportStatusToPlaylists < ActiveRecord::Migration[8.1]
  def change
    add_column :playlists, :import_status, :string
  end
end
