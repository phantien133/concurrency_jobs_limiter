class ConcurrencyLimiter::Config
  include ConcurrencyLimiter::Const

  class << self
    def generate_queue_store_name concurrency_queue
      [self::DATA_KEY_PREFIX, :Job, concurrency_queue].join self::KEY_SERATOR
    end

    def queue &block
      instance_eval(&block) unless Rails.env.test?
    end

    private
    def concurrency_num queue_name, concurrency: 1
      queue = generate_queue_store_name queue_name
      redis = ConcurrencyLimiter::RedisConnection.new prefix: queue
      redis.delete_by id: self::RUNNING_JOB_IDS_KEY
      ConcurrencyLimiter::Queue.process concurrency_queue: queue_name
      ConcurrencyLimiter::Queue.set_concurrency_queue concurrency_queue: queue_name, num: concurrency
    end
  end
end
