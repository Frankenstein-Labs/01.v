# frozen_string_literal: true

require "spec_helper"

RSpec.describe ComplianceManagement::StandardsAdherenceChecksTracker, :freeze_time, :clean_gitlab_redis_shared_state,
  feature_category: :compliance_management do
  let_it_be(:group_id) { 1 }
  let_it_be(:tracker) { described_class.new(group_id) }

  describe '#redis_key' do
    it 'returns the correct name of the redis key for the group' do
      expect(tracker.redis_key).to eq("group:1:progress_of_standards_adherence_checks")
    end
  end

  describe '#track_progress' do
    it 'initialises the redis hash set for the group and sets a ttl of one day' do
      expect(tracker.progress).to eq({})

      tracker.track_progress(3)

      expect(tracker.progress)
        .to eq({ checks_completed: "0", started_at: Time.current.utc.to_s, total_checks: "3" })

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.ttl(tracker.redis_key)).to eq(86400)
      end
    end
  end

  describe '#already_enqueued?' do
    it 'returns true if redis key for that group already exists' do
      expect(tracker.already_enqueued?).to be(false)

      tracker.track_progress(3)

      expect(tracker.already_enqueued?).to be(true)
    end
  end

  describe '#update_progress' do
    context 'when key for the group does not exist' do
      it 'is a no op' do
        expect(tracker.progress).to eq({})

        tracker.update_progress

        expect(tracker.progress).to eq({})
      end
    end

    context 'when key for the group exists' do
      before do
        tracker.track_progress(3)
      end

      it 'updates the progress', :aggregate_failures do
        expect(tracker.progress)
          .to eq({ checks_completed: "0", started_at: Time.current.utc.to_s, total_checks: "3" })

        tracker.update_progress

        expect(tracker.progress)
          .to eq({ checks_completed: "1", started_at: Time.current.utc.to_s, total_checks: "3" })
      end
    end
  end

  describe '#progress' do
    context 'when key does not exist for the group' do
      it 'returns an empty hash' do
        expect(tracker.progress).to eq({})
      end
    end

    context 'when key exists for the group' do
      before do
        tracker.track_progress(3)
      end

      it 'returns the current progress of adherence checks for the group' do
        expect(tracker.progress)
          .to eq({ checks_completed: "0", started_at: Time.current.utc.to_s, total_checks: "3" })
      end
    end
  end
end
