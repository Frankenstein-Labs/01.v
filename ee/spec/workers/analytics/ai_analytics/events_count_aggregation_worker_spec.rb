# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::EventsCountAggregationWorker, :clean_gitlab_redis_shared_state, feature_category: :value_stream_management do
  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    let(:worker) { described_class.new }
    let(:initial_cursor) { 100 }
    let(:new_cursor) { 200 }
    let(:service_response) { { last_processed_id: new_cursor } }
    let(:runtime_limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter) }
    let(:service) { instance_double(Analytics::AiAnalytics::UsageEventsCounterService, execute: service_response) }
    let(:cursor_key) { described_class::CURSOR_KEY }

    before do
      allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(runtime_limiter)
      allow(Analytics::AiAnalytics::UsageEventsCounterService).to receive(:new).and_return(service)
    end

    context 'when cursor exists in Redis' do
      before do
        Gitlab::Redis::SharedState.with { |redis| redis.set(cursor_key, initial_cursor) }
      end

      it 'calls the service with the loaded cursor and runtime limiter' do
        expect(Analytics::AiAnalytics::UsageEventsCounterService).to receive(:new)
          .with(cursor: initial_cursor, runtime_limiter: runtime_limiter)
          .and_return(service)

        worker.perform
      end

      it 'persists the new cursor to Redis' do
        worker.perform

        cursor = Gitlab::Redis::SharedState.with { |redis| redis.get(cursor_key) }
        expect(cursor).to eq(new_cursor.to_s)
      end
    end

    context 'when cursor does not exist in Redis' do
      let(:minimum_id) { 1 }

      before do
        Gitlab::Redis::SharedState.with { |redis| redis.del(cursor_key) }
        allow(Ai::UsageEvent).to receive(:minimum).with(:id).and_return(minimum_id)
      end

      it 'calls the service with the minimum id' do
        expect(Analytics::AiAnalytics::UsageEventsCounterService).to receive(:new)
          .with(cursor: minimum_id, runtime_limiter: runtime_limiter)
          .and_return(service)

        worker.perform
      end

      it 'persists the new cursor to Redis' do
        worker.perform

        cursor = Gitlab::Redis::SharedState.with { |redis| redis.get(cursor_key) }
        expect(cursor).to eq(new_cursor.to_s)
      end
    end

    context 'when Ai::EventsCount is empty' do
      before do
        Gitlab::Redis::SharedState.with { |redis| redis.del(cursor_key) }
        allow(Ai::UsageEvent).to receive(:minimum).with(:id).and_return(nil)
      end

      it 'does not call count service' do
        expect(Analytics::AiAnalytics::UsageEventsCounterService).not_to receive(:new)

        worker.perform
      end
    end

    context 'when service raises an exception' do
      let(:service_error) { StandardError.new('Any error') }
      let(:service_response) do
        {
          exception: service_error,
          last_processed_id: new_cursor
        }
      end

      before do
        Gitlab::Redis::SharedState.with { |redis| redis.set(cursor_key, initial_cursor) }
        allow(service).to receive(:execute).and_return(service_response)
      end

      it 're raises the exception from the service' do
        expect { worker.perform }.to raise_error(StandardError, 'Any error')
      end

      it 'persists the cursor even when exception is raised' do
        expect { worker.perform }.to raise_error(StandardError)

        persisted_cursor = Gitlab::Redis::SharedState.with { |redis| redis.get(cursor_key) }
        expect(persisted_cursor.to_i).to eq(new_cursor)
      end
    end
  end
end
