# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiUserMetricsDatabaseWriteBuffer, feature_category: :devops_reports do
  let(:model_name) { 'test_model' }

  subject(:buffer) { described_class.new(buffer_key: model_name) }

  describe '#add', :clean_gitlab_redis_shared_state do
    it 'adds given attributes json to test_model_db_write_buffer redis hash' do
      buffer.add({ user_id: '1', foo: 'bar' })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.hgetall('test_model_db_write_buffer')).to eq({ '1' => { user_id: '1', foo: 'bar' }.to_json })
      end
    end

    it 'refreshes attributes json if hash already exists' do
      buffer.add({ user_id: 1, foo: 'bar' })
      buffer.add({ user_id: 1, foo: 'baz' })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.hgetall('test_model_db_write_buffer')).to eq({ '1' => { user_id: 1, foo: 'baz' }.to_json })
      end
    end
  end

  describe '#pop', :clean_gitlab_redis_shared_state do
    it 'pops limited array of elements from test_model_db_write_buffer key' do
      buffer.add({ user_id: 1, foo: 'bar' })
      buffer.add({ user_id: 2, foo: 'baz' })
      buffer.add({ user_id: 3, foo: 'bad' })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.hlen('test_model_db_write_buffer')).to eq(3)
      end
      expect(buffer.pop(2)).to eq([{ 'user_id' => 1, 'foo' => 'bar' }, { 'user_id' => 2, 'foo' => 'baz' }])
      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.hlen('test_model_db_write_buffer')).to eq(1)
      end
      expect(buffer.pop(2)).to eq([{ 'user_id' => 3, 'foo' => 'bad' }])
      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.hlen('test_model_db_write_buffer')).to eq(0)
      end
    end
  end
end
