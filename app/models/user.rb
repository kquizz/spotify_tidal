class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def tidal_connected?
    tidal_access_token.present?
  end

  def spotify_connected?
    spotify_access_token.present?
  end

  def spotify_token_expired?
    spotify_expires_at.present? && spotify_expires_at < Time.current
  end

  def tidal_token_expired?
    tidal_expires_at.present? && tidal_expires_at < Time.current
  end
end
