class PlaylistSong < ApplicationRecord
  belongs_to :playlist
  belongs_to :song

  validates :playlist_id, presence: true
  validates :song_id, presence: true
  validates :playlist_id, uniqueness: { scope: :song_id, message: "Song already exists in this playlist" }
end
