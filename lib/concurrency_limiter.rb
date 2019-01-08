require 'rails'
require 'redis'

module ConcurrencyLimiter
end
require_relative "concurrency_limiter/blocker"
require_relative "concurrency_limiter/redis_connection"
