# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::CircuitBreaker,
  :clean_gitlab_redis_shared_state,
  feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:destination) do
    create(:audit_events_group_external_streaming_destination, group: group)
  end

  let_it_be(:instance_destination) do
    create(:audit_events_instance_external_streaming_destination)
  end

  describe '.open?' do
    it 'returns false initially' do
      expect(described_class.open?(destination)).to be(false)
    end

    it 'returns true after the breaker has been tripped' do
      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }

      expect(described_class.open?(destination)).to be(true)
    end

    it 'sets the open key with the OPEN_DURATION TTL so it auto-expires' do
      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }

      ttl = Gitlab::Redis::SharedState.with do |redis|
        redis.ttl(format(described_class::OPEN_KEY_FORMAT, scope: 'group', id: destination.id))
      end

      # Redis TTL is set to OPEN_DURATION on trip; allow a small leeway for
      # the small time elapsed between SET and TTL read.
      expect(ttl).to be_between(described_class::OPEN_DURATION.to_i - 5, described_class::OPEN_DURATION.to_i)
    end

    it 'returns false again once the open key has expired' do
      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }

      # Simulate TTL expiry by deleting the key; Redis itself ignores
      # travel_to, so we mimic the expiration directly.
      Gitlab::Redis::SharedState.with do |redis|
        redis.del(format(described_class::OPEN_KEY_FORMAT, scope: 'group', id: destination.id))
      end

      expect(described_class.open?(destination)).to be(false)
    end

    it 'segregates group and instance destinations by scope', :aggregate_failures do
      # Tripping a group destination must not affect an instance destination
      # with the same numeric id.
      allow(instance_destination).to receive(:id).and_return(destination.id)

      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }

      expect(described_class.open?(destination)).to be(true)
      expect(described_class.open?(instance_destination)).to be(false)
    end

    context 'when Redis raises an error' do
      before do
        allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(::Redis::BaseError)
      end

      it 'returns false and logs the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(::Redis::BaseError))

        expect(described_class.open?(destination)).to be(false)
      end
    end
  end

  describe '.record_failure' do
    it 'does not trip the breaker before the threshold' do
      (described_class::FAILURE_THRESHOLD - 1).times { described_class.record_failure(destination) }

      expect(described_class.open?(destination)).to be(false)
    end

    it 'trips the breaker exactly at the threshold' do
      (described_class::FAILURE_THRESHOLD - 1).times { described_class.record_failure(destination) }
      expect(described_class.open?(destination)).to be(false)

      described_class.record_failure(destination)
      expect(described_class.open?(destination)).to be(true)
    end

    it 'sets the failure counter with the FAILURE_WINDOW TTL' do
      described_class.record_failure(destination)

      ttl = Gitlab::Redis::SharedState.with do |redis|
        redis.ttl(format(described_class::FAILURE_KEY_FORMAT, scope: 'group', id: destination.id))
      end

      expect(ttl).to be_between(described_class::FAILURE_WINDOW.to_i - 5, described_class::FAILURE_WINDOW.to_i)
    end

    it 'does not count failures separated by more than FAILURE_WINDOW toward the same trip' do
      (described_class::FAILURE_THRESHOLD - 1).times { described_class.record_failure(destination) }

      # Simulate the FAILURE_WINDOW sliding-window TTL elapsing by deleting
      # the counter directly; Redis ignores travel_to.
      Gitlab::Redis::SharedState.with do |redis|
        redis.del(format(described_class::FAILURE_KEY_FORMAT, scope: 'group', id: destination.id))
      end

      described_class.record_failure(destination)

      expect(described_class.open?(destination)).to be(false)
    end

    it 'logs a warning and increments the prometheus counter on trip' do
      expect(Gitlab::AppLogger).to receive(:warn).with(
        hash_including(
          message: 'Audit event streaming destination disabled by circuit breaker',
          destination_id: destination.id,
          destination_name: destination.name,
          destination_category: destination.category,
          destination_scope: 'group',
          disabled_for_seconds: described_class::OPEN_DURATION.to_i
        )
      )

      expect(AuditEvents::AuditEventStreamingWorker::CIRCUIT_BREAKER_COUNTER)
        .to receive(:increment)
        .with(scope: 'group', category: destination.category.to_s)

      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }
    end

    it 'does not notify again on subsequent failures while the breaker is open' do
      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(destination) }

      expect(Gitlab::AppLogger).not_to receive(:warn)
      expect(AuditEvents::AuditEventStreamingWorker::CIRCUIT_BREAKER_COUNTER).not_to receive(:increment)

      described_class.record_failure(destination)
    end

    context 'when Redis raises an error' do
      before do
        allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(::Redis::BaseError)
      end

      it 'logs and swallows the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(::Redis::BaseError))

        expect { described_class.record_failure(destination) }.not_to raise_error
      end
    end
  end

  describe '.record_success' do
    it 'clears the failure counter so the breaker does not trip on a slow accumulation' do
      (described_class::FAILURE_THRESHOLD - 1).times { described_class.record_failure(destination) }

      described_class.record_success(destination)
      described_class.record_failure(destination)

      expect(described_class.open?(destination)).to be(false)
    end
  end

  describe '.reject_open' do
    let(:open_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    let(:closed_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    it 'filters out destinations whose breaker is open' do
      described_class::FAILURE_THRESHOLD.times { described_class.record_failure(open_destination) }

      result = described_class.reject_open([open_destination, closed_destination])

      expect(result).to contain_exactly(closed_destination)
    end

    it 'returns the input unchanged when no destinations are open' do
      other = create(:audit_events_group_external_streaming_destination, group: group)

      result = described_class.reject_open([closed_destination, other])

      expect(result).to contain_exactly(closed_destination, other)
    end

    it 'returns the empty array when given an empty array' do
      expect(described_class.reject_open([])).to eq([])
    end

    context 'when Redis raises an error during the MGET' do
      it 'returns the destinations unchanged and logs the error' do
        # Stub only the mget call so the enabled? check and any prior
        # record_failure setup run normally.
        allow(Gitlab::Redis::SharedState).to receive(:with).and_call_original
        allow(Gitlab::Redis::SharedState).to receive(:with).once.and_raise(::Redis::BaseError)

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(::Redis::BaseError))

        result = described_class.reject_open([open_destination, closed_destination])

        expect(result).to contain_exactly(open_destination, closed_destination)
      end
    end
  end
end
