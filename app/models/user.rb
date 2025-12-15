class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def tidal_connected?
    tidal_access_token.present?
  end

  def tidal_token_expired?
    tidal_expires_at.present? && tidal_expires_at < Time.current
  end
end
