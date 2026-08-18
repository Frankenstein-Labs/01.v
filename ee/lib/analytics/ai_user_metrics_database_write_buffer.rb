# frozen_string_literal: true

module Analytics
  # Stores last attributes set for each `user_id` in Redis hash.
  class AiUserMetricsDatabaseWriteBuffer < DatabaseWriteBuffer
    def add(attributes)
      hkey = attributes[:user_id]

      Gitlab::Redis::SharedState.with do |redis|
        redis.hset(buffer_key, hkey.to_s, attributes.to_json)
      end
    end

    def pop(limit)
      Gitlab::Redis::SharedState.with do |redis|
        keys = redis.hkeys(buffer_key)[0..(limit - 1)]

        next [] if keys.empty?

        attributes, _deletes = redis.pipelined do |pipeline|
          pipeline.hmget(buffer_key, *keys)
          pipeline.hdel(buffer_key, keys)
        end

        attributes.compact.map { |attrs| Gitlab::Json.safe_parse(attrs) }
      end
    end
  end
end
