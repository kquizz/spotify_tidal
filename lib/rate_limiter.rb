# frozen_string_literal: true

# Simple in-memory rate limiter using Redis-like sliding window algorithm
# For production, consider using Redis with the 'redis-rb' and 'redis-throttle' gems
class RateLimiter
  class RateLimitExceeded < StandardError; end

  def initialize
    @requests = {}
    @mutex = Mutex.new
  end

  # Check if request is allowed under rate limit
  # @param key [String] identifier for the rate limit (e.g., "spotify_api", "tidal_api")
  # @param limit [Integer] maximum number of requests allowed
  # @param period [Integer] time window in seconds
  # @return [Boolean] true if request is allowed
  def allowed?(key:, limit:, period:)
    @mutex.synchronize do
      now = Time.current.to_i
      window_start = now - period

      # Initialize or clean up old requests
      @requests[key] ||= []
      @requests[key].reject! { |timestamp| timestamp < window_start }

      # Check if under limit
      if @requests[key].size < limit
        @requests[key] << now
        true
      else
        false
      end
    end
  end

  # Execute block with rate limiting
  # @param key [String] identifier for the rate limit
  # @param limit [Integer] maximum number of requests allowed
  # @param period [Integer] time window in seconds
  # @param wait [Boolean] whether to wait if rate limit is exceeded
  def throttle(key:, limit:, period:, wait: true, &block)
    loop do
      if allowed?(key: key, limit: limit, period: period)
        return yield
      elsif wait
        # Calculate wait time based on oldest request in window
        oldest_request = @requests[key].min
        wait_time = (oldest_request + period) - Time.current.to_i
        Rails.logger.info("Rate limit reached for #{key}. Waiting #{wait_time}s...")
        sleep([ wait_time, 1 ].max)
      else
        raise RateLimitExceeded, "Rate limit exceeded for #{key}"
      end
    end
  end

  # Get remaining requests in current window
  def remaining(key:, limit:, period:)
    @mutex.synchronize do
      now = Time.current.to_i
      window_start = now - period

      @requests[key] ||= []
      @requests[key].reject! { |timestamp| timestamp < window_start }

      [ limit - @requests[key].size, 0 ].max
    end
  end

  # Reset rate limit for a key
  def reset(key:)
    @mutex.synchronize do
      @requests.delete(key)
    end
  end

  # Singleton instance
  def self.instance
    @instance ||= new
  end
end
