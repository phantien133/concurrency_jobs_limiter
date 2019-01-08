# rubocop:disable Naming/UncommunicativeMethodParamName
class ConcurrencyLimiter::RedisConnection
  include ConcurrencyLimiter::Const

  def initialize prefix:
    @prefix = prefix
  end

  def pairing_id id, prefix: nil
    [(prefix || @prefix), id].join KEY_SERATOR
  end

  def save_as_json id:, record:, nx: false, prefix: nil
    redis.set pairing_id(id, prefix: prefix), record.to_json, nx: nx
  end

  def load_to_json id:, prefix: nil
    json_converter redis.get(pairing_id(id, prefix: prefix))
  end

  def delete_by id:, prefix: nil
    redis.del pairing_id(id, prefix: prefix)
  end

  def json_converter json
    JSON.parse json
  rescue JSON::ParserError, TypeError
    nil
  end

  def generate_id id: Time.zone.now.to_i, prefix: nil
    loop do
      key = "#{id}_#{SecureRandom.hex 5}"
      return key if load_to_json(id: id, prefix: prefix).nil?
    end
  end

  def redis
    @redis ||= Redis.current
  end
end
# rubocop:enable Naming/UncommunicativeMethodParamName
