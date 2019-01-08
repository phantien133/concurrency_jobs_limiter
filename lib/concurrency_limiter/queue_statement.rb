module ConcurrencyLimiter::QueueStatement
  extend ActiveSupport::Concern
  include ConcurrencyLimiter::Const

  included do
    def transaction
      ConcurrencyLimiter::Blocker.instance.block_process block_key: [@queue, EXEC_JOB_BLOCK_KEY].join(KEY_SERATOR),
        block_timeout: 5 do
        yield
      end
    end

    def shift!
      transaction do
        job_ids = load_job_ids
        find_by(job_id: job_ids.shift).tap{replace_job_ids_by! job_ids: job_ids}
      end
    end

    def unshift! job
      transaction do
        job_ids = load_job_ids
        job_ids.unshift! job.job_id
        replace_job_ids_by! job_ids: job_ids
        load_job_ids
      end
    end

    def push! job
      transaction do
        job_ids = load_job_ids
        return true if job_ids.include? job.job_id
        job_ids << job.job_id if saved = save(job)
        replace_job_ids_by! job_ids: job_ids if saved && redis.save_as_json(id: job.job_id, record: job)
        load_job_ids
      end
    end

    def save job
      return if job.job_id.nil?
      redis.save_as_json id: job.job_id, record: job
    end

    def destroy job: nil
      return false if job&.job_id.nil? || load_job_ids.exclude?(job.job_id)
      transaction do
        remove_job_data_by! job_ids: job.job_id
        delete job
      end
    end

    def delete job
      redis.delete_by id: job.job_id
    end

    def find_by job_id:
      return if job_id.nil?
      data = load_data_of! job_id: job_id
      data[:validate] = false
      ConcurrencyLimiter::Job.new data
    end

    def load_job_ids
      redis.load_to_json(id: LIST_IDS_KEY).tap do |list|
        raise ConcurrencyLimiter::Exceptions::JobListNotFound, redis.pairing_id(LIST_IDS_KEY) unless list&.is_a? Array
      end
    end

    def generate_id id: Time.zone.now.to_i, prefix: nil
      redis.generate_id id: id, prefix: prefix || @queue
    end

    private
    def remove_job_data_by! job_ids:
      job_ids = [job_ids] unless job_ids&.is_a? Array
      instance_job_ids = load_job_ids
      job_ids.each{|job_id| redis.delete_by id: job_id}
      replace_job_ids_by! job_ids: (instance_job_ids - job_ids)
    end

    def load_data_of! job_id:
      job_attrs = redis.load_to_json id: job_id
      raise ConcurrencyLimiter::Exceptions::JobListNotFound, job_id unless job_attrs.present?
      job_attrs.symbolize_keys! if job_attrs.is_a? Hash
      job_attrs
    end

    def replace_job_ids_by! job_ids:
      raise ConcurrencyLimiter::Exceptions::CanNotUpdateJobs, @job_list unless redis.save_as_json id: LIST_IDS_KEY,
        record: job_ids
    end
  end
end
