class ConcurrencyLimiter::Exceptions::JobNameInvalid < ConcurrencyLimiter::Exceptions::Base
  def initialize job_name
    super "Coun't found job: #{job_name} - job_name invalid"
  end
end
