class Artist < ApplicationRecord
  has_many :songs, dependent: :destroy
  has_many :albums, dependent: :destroy

  validates :name, presence: true
  validates :spotify_id, uniqueness: true, allow_nil: true
end
