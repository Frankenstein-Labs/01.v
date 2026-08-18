# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::RefreshWorker, feature_category: :compliance_management do
  let_it_be(:worker) { described_class.new }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:total_checks) { ComplianceManagement::Standards::RefreshWorker::TOTAL_STANDARDS_ADHERENCE_CHECKS }
  let(:job_args) do
    { 'group_id' => group_id, 'user_id' => user_id }
  end

  describe '#perform' do
    context 'for non existent group' do
      let(:group_id) { non_existing_record_id }
      let(:user_id) { user.id }

      it 'does not enqueue standards adherence check workers' do
        expect(ComplianceManagement::StandardsAdherenceChecksTracker).not_to receive(:new)
        ComplianceManagement::Standards::RefreshWorker::STANDARDS_ADHERENCE_CHECK_WORKERS.each do |worker|
          expect(worker).not_to receive(:perform_async)
        end

        worker.perform(job_args)
      end
    end

    context 'when refresh worker was executed less than 24 hours ago', :clean_gitlab_redis_shared_state do
      let(:group_id) { group.id }
      let(:user_id) { user.id }

      before do
        Gitlab::Redis::SharedState.with do |redis|
          redis.hset("group:#{group_id}:progress_of_standards_adherence_checks", {
            'started_at' => Time.current.utc.to_s,
            'total_checks' => total_checks,
            'checks_completed' => 0
          })
        end
      end

      it 'does not enqueue standards adherence check workers' do
        expect_next_instance_of(ComplianceManagement::StandardsAdherenceChecksTracker, group_id) do |tracker|
          expect(tracker).to receive(:already_enqueued?).and_call_original
        end

        ComplianceManagement::Standards::RefreshWorker::STANDARDS_ADHERENCE_CHECK_WORKERS.each do |worker|
          expect(worker).not_to receive(:perform_async)
        end

        worker.perform(job_args)
      end
    end

    context 'when refresh worker was not executed less than 24 hours ago' do
      let(:user_id) { user.id }
      let(:group_id) { group.id }

      it 'enqueues standards adherence check workers', :aggregate_failures do
        expect_next_instance_of(ComplianceManagement::StandardsAdherenceChecksTracker, group_id) do |tracker|
          expect(tracker).to receive(:already_enqueued?).and_call_original
        end

        expect_next_instance_of(ComplianceManagement::StandardsAdherenceChecksTracker, group_id) do |tracker|
          expect(tracker).to receive(:track_progress).and_call_original
        end

        expect(ComplianceManagement::Standards::RefreshWorker::STANDARDS_ADHERENCE_CHECK_WORKERS)
          .to all receive(:perform_async).with(
            { 'group_id' => group_id, 'user_id' => user_id, 'track_progress' => true })

        worker.perform(job_args)
      end
    end

    it 'includes all the adherence check workers' do
      expect(total_checks).to eq(Enums::Projects::ComplianceStandards::Adherence.check_name.count)
    end

    it_behaves_like 'an idempotent worker' do
      let(:user_id) { user.id }
      let(:group_id) { group.id }
    end
  end
end
