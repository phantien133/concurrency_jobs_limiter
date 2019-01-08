class ConcurrencyLimiter::Exceptions::CanNotUpdateJobs < ConcurrencyLimiter::Exceptions::Base
  def initialize list_name
    super "Can not update jobs db: #{list_name}"
  end
end
