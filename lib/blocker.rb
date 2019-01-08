module Blocker
  attr_accessor :block_key, :delay_in
  DEFAULT_LOCK_PROCESS_OPTION = {block_time: 1, block_timeout: 10, random_delay: 100..900}
  BLOCK_KEY_TIMEOUT = 1.hour

  def block_process options = {}
    options = DEFAULT_LOCK_PROCESS_OPTION.merge options
    lock_key = "#{options[:block_key] || block_key}_lock"
    latest_call_key = "#{lock_key}_locked_at"
    redis = Redis.current
    random_sleep options[:random_delay] until redis.set lock_key, Time.zone.now.to_i, nx: true,
        ex: options[:block_timeout]
    wait options[:block_time], redis.get(latest_call_key)
    result = yield
    redis.set latest_call_key, Time.zone.now.to_f, ex: BLOCK_KEY_TIMEOUT
    result
  ensure
    redis.del lock_key
  end

  private
  def random_sleep range
    sleep rand(range || delay_in) / 1000.0
  end

  def wait block_time, last_called_at
    remain_lock_time = block_time - (Time.zone.now - Time.zone.at(last_called_at.to_f)).round(1)
    sleep remain_lock_time if remain_lock_time.positive?
  end
end
