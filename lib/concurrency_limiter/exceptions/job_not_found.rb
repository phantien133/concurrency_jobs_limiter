class ConcurrencyLimiter::Exceptions::JobListNotFound < ConcurrencyLimiter::Exceptions::Base
  def initialize job_id
    super "Coun't found job by: #{job_id}"
  end
end
