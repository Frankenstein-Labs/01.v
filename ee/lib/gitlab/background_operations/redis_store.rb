# frozen_string_literal: true

module Gitlab
  module BackgroundOperations
    class RedisStore
      EXPIRY = 72.hours
      KEY_PREFIX = 'background_operation'

      Operation = Struct.new(
        :id, :operation_type, :user_id,
        :parameters, :total_items, :successful_items, :failed_items,
        keyword_init: true
      )

      def self.create_operation(operation_type:, user_id:, total_items:, parameters: {})
        operation_id = "#{operation_type}_#{user_id}_#{Time.current.to_i}_#{SecureRandom.hex(4)}"

        data = {
          'id' => operation_id,
          'operation_type' => operation_type,
          'user_id' => user_id,
          'parameters' => parameters.to_json,
          'status' => 'pending',
          'total_items' => total_items,
          'successful_items' => 0,
          'failed_items' => 0
        }

        with_redis_and_expiry(operation_key(operation_id)) do |redis|
          redis.hset(operation_key(operation_id), data)
        end

        operation_id
      end

      def self.increment_successful(operation_id, count = 1)
        with_redis_and_expiry(operation_key(operation_id)) do |redis|
          redis.hincrby(operation_key(operation_id), 'successful_items', count)
        end
      end

      def self.add_failed_item(
        operation_id, entity_id:, entity_type:, error_message:,
        entity_name: nil, entity_full_path: nil
      )
        item = {
          'entity_id' => entity_id,
          'entity_type' => entity_type,
          'entity_name' => entity_name,
          'entity_full_path' => entity_full_path,
          'error_message' => error_message
        }.compact

        op_key = operation_key(operation_id)
        failed_key = failed_items_key(operation_id)

        with_redis_and_expiry(op_key, failed_key) do |redis|
          redis.lpush(failed_key, item.to_json)
          redis.hincrby(op_key, 'failed_items', 1)
        end
      end

      def self.get_operation(operation_id)
        with_redis do |redis|
          data = redis.hgetall(operation_key(operation_id))
          break nil if data.empty?

          parse_operation(data)
        end
      end

      def self.get_failed_items(operation_id)
        with_redis do |redis|
          items = redis.lrange(failed_items_key(operation_id), 0, -1)
          items.map { |item| ::Gitlab::Json.safe_parse(item) }
        end
      end

      def self.delete_operation(operation_id)
        with_redis do |redis|
          redis.del(operation_key(operation_id))
          redis.del(failed_items_key(operation_id))
        end
      end

      def self.operation_key(operation_id)
        "#{KEY_PREFIX}:#{operation_id}"
      end

      def self.failed_items_key(operation_id)
        "#{KEY_PREFIX}:#{operation_id}:failed_items"
      end

      def self.parse_operation(data)
        Operation.new(
          id: data['id'],
          operation_type: data['operation_type'],
          user_id: data['user_id'].to_i,
          parameters: ::Gitlab::Json.safe_parse(data['parameters']) || {},
          total_items: data['total_items'].to_i,
          successful_items: data['successful_items'].to_i,
          failed_items: data['failed_items'].to_i
        )
      end

      def self.with_redis
        Gitlab::Redis::SharedState.with { |redis| yield redis }
      end

      def self.with_redis_and_expiry(*keys)
        with_redis do |redis|
          result = yield redis
          keys.each { |key| redis.expire(key, EXPIRY) }
          result
        end
      end
    end
  end
end
