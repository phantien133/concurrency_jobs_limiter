class ConcurrencyLimiter::Exceptions::JobListNotFound < ConcurrencyLimiter::Exceptions::Base
  def initialize list_name
    super "Coun't found job list: #{list_name} - Missing list_name"
  end
end
