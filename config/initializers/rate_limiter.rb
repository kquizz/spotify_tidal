# frozen_string_literal: true

# Rate limiter configuration
# Spotify API limits: ~180 requests per minute per user
# Tidal API limits: Not publicly documented, but conservative limits recommended

Rails.application.config.to_prepare do
  # Load rate limiter
  require_dependency Rails.root.join("lib", "rate_limiter")

  # Initialize rate limiter singleton
  Rails.application.config.rate_limiter = RateLimiter.instance

  # Configure rate limits
  Rails.application.config.api_rate_limits = {
    spotify: {
      limit: 150,  # Conservative limit (Spotify allows ~180/min)
      period: 60   # 60 seconds
    },
    tidal: {
      limit: 100,  # Conservative limit
      period: 60   # 60 seconds
    }
  }
end
