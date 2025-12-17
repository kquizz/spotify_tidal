class Album < ApplicationRecord
  belongs_to :artist
  has_many :songs, dependent: :destroy

  validates :name, presence: true
  validates :spotify_id, uniqueness: true, allow_nil: true
end
