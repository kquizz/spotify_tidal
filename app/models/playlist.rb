class Playlist < ApplicationRecord
  has_many :playlist_songs, dependent: :destroy
  has_many :songs, through: :playlist_songs

  validates :name, presence: true
  validates :spotify_id, presence: true, uniqueness: true
  validates :import_status, inclusion: { in: %w[pending in_progress completed failed], allow_nil: true }
end
