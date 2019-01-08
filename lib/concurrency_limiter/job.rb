class ConcurrencyLimiter::Job
  include ConcurrencyLimiter::Const

  JOB_ARGUMENTS = %i(job execute_args concurrency_queue)
  STORE_ATTRIBUTES = %i(job_registered_at job_updated_at job_id)

  attr_reader(*STORE_ATTRIBUTES)
  attr_accessor(*JOB_ARGUMENTS)

  class << self
    def register! *args
      new(*args).save!
    end

    def clean_job_args arguments
      args = arguments.clone
      job_args = args.extract_options!.symbolize_keys!
      is_concurrency_execute = job_args[:concurrency_limiter] && job_args[:job_id].present?
      args = arguments unless is_concurrency_execute
      [args, job_args[:job_id], is_concurrency_execute]
    end
  end

  def initialize job:, concurrency_queue:, execute_args: [], job_updated_at: nil,
    job_registered_at: nil, job_id: nil, validate: true
    set_instance_variables_by_hash JOB_ARGUMENTS, job: job, execute_args: execute_args,
      concurrency_queue: concurrency_queue
    validate_args! if validate
    return if job_id.blank?
    set_instance_variables_by_hash STORE_ATTRIBUTES, job_updated_at: job_updated_at,
      job_registered_at: job_registered_at, job_id: job_id
  end

  def persisted?
    @job_id.present?
  end

  def to_json
    (JOB_ARGUMENTS + STORE_ATTRIBUTES).each_with_object(as_hash = {}) do |key, hash|
      hash[key] = public_send key
    end
    as_hash.to_json
  end

  def save!
    validate_args!
    update_timestamps
    generate_job_id unless persisted?
    queue.push! self
  end

  def update! *args
    set_instance_variables_by_hash JOB_ARGUMENTS, *args
    save!
  end

  def delete
    queue.delete self
  end

  def destroy
    queue.destroy job: self
  end

  def queue
    @queue ||= ConcurrencyLimiter::Queue.new concurrency_queue: @concurrency_queue
  end

  def change_queue concurrency_queue:
    @concurrency_queue = concurrency_queue
    @queue = ConcurrencyLimiter::Queue.new concurrency_queue: concurrency_queue
  end

  def perform
    # #TODO implement by Adapter
    raise NotImplementedError, "Check your adapter config ActiveJob|Sidekiq Worker"
  end

  private
  def generate_job_id
    @job_id = queue.generate_id unless @job_id.present?
  end

  def define_timestamps_variables
    @job_registered_at = nil
    @job_updated_at = nil
  end

  def update_timestamps
    @job_registered_at ||= Time.zone.now
    @job_updated_at = persisted? ? Time.zone.now : @job_registered_at
  end

  def set_instance_variables *args
    set_instance_variables_by_hash JOB_ARGUMENTS, *args
    set_instance_variables_by_hash STORE_ATTRIBUTES, *args
    load_job_class!
  end

  def instance_job
    @job.singularize.classify.constantize
  end

  def load_job_class!
    @job = @job.name if @job.is_a? Class
    instance_job
  rescue NameError
    raise ConcurrencyLimiter::Exceptions::JobNameInvalid, @job
  end

  def set_instance_variables_by_hash variable_names, *args
    args = args.extract_options!.symbolize_keys
    variable_names.each do |attr|
      instance_variable_set "@#{attr}", args[attr]
    end
  end

  def validate_args!
    ConcurrencyLimiter::Job::JOB_ARGUMENTS.each do |arg|
      raise ArgumentError, "#{arg} can't be nil" if instance_variable_get(:"@#{arg}").nil?
    end
    load_job_class!
  end
end
