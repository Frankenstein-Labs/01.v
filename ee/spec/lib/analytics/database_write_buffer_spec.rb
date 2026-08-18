# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::DatabaseWriteBuffer, feature_category: :devops_reports do
  let(:model_name) { 'test_model' }

  subject(:buffer) { described_class.new(buffer_key: model_name) }

  describe '#add', :clean_gitlab_redis_shared_state do
    it 'adds given attributes json to test_model_db_write_buffer redis list' do
      buffer.add({ foo: 'bar' })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.lindex('test_model_db_write_buffer', 0)).to eq({ foo: 'bar' }.to_json)
      end
    end

    it 'adds multiple attributes json to test_model_db_write_buffer redis list' do
      buffer.add([{ foo: 'bar' }, { foo: 'baz' }])

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.lindex('test_model_db_write_buffer', 0)).to eq({ foo: 'bar' }.to_json)
        expect(redis.lindex('test_model_db_write_buffer', 1)).to eq({ foo: 'baz' }.to_json)
      end
    end
  end

  describe '#pop', :clean_gitlab_redis_shared_state do
    it 'pops limited array of elements from test_model_db_write_buffer key' do
      buffer.add({ foo: 'bar' })
      buffer.add({ foo: 'baz' })
      buffer.add({ foo: 'bad' })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.llen('test_model_db_write_buffer')).to eq(3)
      end
      expect(buffer.pop(2)).to eq([{ 'foo' => 'bar' }, { 'foo' => 'baz' }])
      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.llen('test_model_db_write_buffer')).to eq(1)
      end
      expect(buffer.pop(2)).to eq([{ 'foo' => 'bad' }])
      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.llen('test_model_db_write_buffer')).to eq(0)
      end
    end
  end
end
