# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::RefreshCooldown, :clean_gitlab_redis_shared_state,
  feature_category: :dependency_management do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:other_merge_request) { create(:merge_request) }

  def ttl_for(record)
    Gitlab::Redis::SharedState.with do |redis|
      redis.ttl("#{described_class::KEY_PREFIX}:#{record.id}")
    end
  end

  describe '.elapsed?' do
    it 'is true when no window is open' do
      expect(described_class.elapsed?(merge_request)).to be(true)
    end

    it 'is false for the rest of the window it just consumed' do
      described_class.elapsed?(merge_request)

      expect(described_class.elapsed?(merge_request)).to be(false)
    end

    it 'tracks each merge request separately' do
      described_class.elapsed?(merge_request)

      expect(described_class.elapsed?(other_merge_request)).to be(true)
    end

    it 'opens a window lasting the full period' do
      described_class.elapsed?(merge_request)

      expect(ttl_for(merge_request)).to be_within(5).of(described_class::PERIOD.to_i)
    end

    it 'does not push out a window that is already open' do
      described_class.elapsed?(merge_request)

      Gitlab::Redis::SharedState.with do |redis|
        redis.expire("#{described_class::KEY_PREFIX}:#{merge_request.id}", 60)
      end

      described_class.elapsed?(merge_request)

      expect(ttl_for(merge_request)).to be_within(5).of(60)
    end

    it 'is true again once the window has expired' do
      described_class.elapsed?(merge_request)

      Gitlab::Redis::SharedState.with do |redis|
        redis.del("#{described_class::KEY_PREFIX}:#{merge_request.id}")
      end

      expect(described_class.elapsed?(merge_request)).to be(true)
    end
  end

  context 'when Redis is unreachable' do
    before do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(Redis::BaseError)
    end

    it 'reports the window as not elapsed rather than raising' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(described_class.elapsed?(merge_request)).to be(false)
    end

    it 'does not raise when starting a window' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect { described_class.start(merge_request) }.not_to raise_error
    end
  end

  describe '.start' do
    it 'closes the window so the merge request is not immediately re-resolved' do
      described_class.start(merge_request)

      expect(described_class.elapsed?(merge_request)).to be(false)
    end

    it 'restarts a window that is already open' do
      described_class.elapsed?(merge_request)

      Gitlab::Redis::SharedState.with do |redis|
        redis.expire("#{described_class::KEY_PREFIX}:#{merge_request.id}", 60)
      end

      described_class.start(merge_request)

      expect(ttl_for(merge_request)).to be_within(5).of(described_class::PERIOD.to_i)
    end
  end
end
