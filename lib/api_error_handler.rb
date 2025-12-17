# frozen_string_literal: true

module ApiErrorHandler
  class ApiError < StandardError
    attr_reader :response, :status_code

    def initialize(message, response: nil, status_code: nil)
      @response = response
      @status_code = status_code
      super(message)
    end
  end

  class RateLimitError < ApiError; end
  class AuthenticationError < ApiError; end
  class NotFoundError < ApiError; end
  class ServerError < ApiError; end

  def handle_api_response(response, context: "API request")
    return response if response.success?

    error_message = "#{context} failed: #{response.status}"

    case response.status
    when 401, 403
      Rails.logger.error("#{context} - Authentication error: #{response.status}")
      raise AuthenticationError.new(error_message, response: response, status_code: response.status)
    when 404
      Rails.logger.warn("#{context} - Not found: #{response.status}")
      raise NotFoundError.new(error_message, response: response, status_code: response.status)
    when 429
      Rails.logger.warn("#{context} - Rate limit exceeded")
      raise RateLimitError.new(error_message, response: response, status_code: response.status)
    when 500..599
      Rails.logger.error("#{context} - Server error: #{response.status}")
      raise ServerError.new(error_message, response: response, status_code: response.status)
    else
      Rails.logger.error("#{context} - Unknown error: #{response.status}")
      raise ApiError.new(error_message, response: response, status_code: response.status)
    end
  end

  def with_retry(max_attempts: 3, backoff: 2, on: [ ApiError ], context: "Operation")
    attempts = 0
    begin
      attempts += 1
      yield
    rescue *on => e
      if attempts < max_attempts
        sleep_time = backoff ** attempts
        Rails.logger.warn("#{context} failed (attempt #{attempts}/#{max_attempts}). Retrying in #{sleep_time}s... Error: #{e.message}")
        sleep(sleep_time)
        retry
      else
        Rails.logger.error("#{context} failed after #{max_attempts} attempts. Error: #{e.message}")
        raise
      end
    end
  end

  def build_faraday_connection(base_url, timeout: 30)
    Faraday.new(url: base_url) do |conn|
      conn.options.timeout = timeout
      conn.options.open_timeout = 10
      conn.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        exceptions: [
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          "Timeout::Error"
        ],
        methods: %i[get post put delete],
        retry_statuses: [ 429, 500, 502, 503, 504 ]
      }
      conn.adapter Faraday.default_adapter
    end
  end

  def with_rate_limit(service:, &block)
    return yield unless Rails.application.config.respond_to?(:rate_limiter)

    rate_limiter = Rails.application.config.rate_limiter
    limits = Rails.application.config.api_rate_limits[service.to_sym]

    return yield unless limits

    rate_limiter.throttle(
      key: service.to_s,
      limit: limits[:limit],
      period: limits[:period],
      wait: true,
      &block
    )
  rescue RateLimiter::RateLimitExceeded => e
    Rails.logger.error("Rate limit exceeded for #{service}: #{e.message}")
    raise RateLimitError.new("Rate limit exceeded for #{service}")
  end
end
