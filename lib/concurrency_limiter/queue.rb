class ConcurrencyLimiter::Queue
  include ConcurrencyLimiter::Const
  include ConcurrencyLimiter::QueueStatement

  attr_reader :concurrency_queue, :queue, :redis

  class << self
    def push concurrency_queue:, job:
      new(concurrency_queue: concurrency_queue).push job
    end

    def process concurrency_queue:
      new(concurrency_queue: concurrency_queue).process
    end

    def execute concurrency_queue:, job_id:
      new(concurrency_queue: concurrency_queue).execute job_id
    end

    def set_concurrency_queue concurrency_queue:, num:
      new(concurrency_queue: concurrency_queue).set_concurrency_queue num: num
    end
  end

  def initialize concurrency_queue:
    @concurrency_queue = concurrency_queue
    @queue = ConcurrencyLimiter::Config.generate_queue_store_name @concurrency_queue
    @redis = ConcurrencyLimiter::RedisConnection.new prefix: @queue
    @redis.save_as_json id: LIST_IDS_KEY, record: [], nx: true
  end

  def process
    return if overrunning_queue? || (job = shift!).nil?
    start_running_job job
    job.perform
  end

  def any?
    load_job_ids.any?
  end

  def overrunning_queue?
    runing_job_ids.present? && runing_job_ids.length >= concurrency_num
  end

  def runing_job_ids
    redis.load_to_json(id: RUNNING_JOB_IDS_KEY) || []
  end

  def concurrency_num
    concurrency_options["num"]
  end

  def concurrency_options
    redis.load_to_json(id: CONCURRENCY_OPTION_KEY) || {}
  end

  def execute job_id
    job_ids = runing_job_ids
    job_ids.delete job_id
    save_running_job_ids job_ids
    redis.delete_by id: job_id
  ensure
    process
  end

  def set_concurrency_queue *args
    redis.save_as_json id: CONCURRENCY_OPTION_KEY, record: args.extract_options!
  end

  private
  def start_running_job job
    job_ids = runing_job_ids
    save_running_job_ids(job_ids << job.job_id)
  end

  def save_running_job_ids job_ids
    redis.save_as_json id: RUNNING_JOB_IDS_KEY, record: job_ids
  end
end
