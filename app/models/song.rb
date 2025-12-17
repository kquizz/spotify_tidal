class Song < ApplicationRecord
  belongs_to :artist
  belongs_to :album
  has_many :playlist_songs, dependent: :destroy
  has_many :playlists, through: :playlist_songs

  validates :name, presence: true
  validates :spotify_id, presence: true, uniqueness: true
end
