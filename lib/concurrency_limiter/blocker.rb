require_relative "./../blocker"

class ConcurrencyLimiter::Blocker
  include Singleton
  include Blocker
end
