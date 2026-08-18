# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::ScheduleWorker, '#perform', feature_category: :security_policy_management do
  include ExclusiveLeaseHelpers

  let_it_be(:time_window) { 3.hours.to_i }
  let_it_be_with_refind(:schedule) do
    create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
  end

  subject(:perform) { described_class.new.perform }

  before do
    schedule.update!(next_run_at: 1.hour.ago)
  end

  it 'does not enqueue any run workers when license feature is not available' do
    expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
      .not_to receive(:perform_async)

    perform
  end

  context 'when feature is available' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    it_behaves_like 'an idempotent worker' do
      it 'enqueues the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
          .to receive(:perform_async).with(schedule.id, { 'branch' => 'main' })

        perform
      end

      it 'updates next_run_at' do
        expect { perform }.to change { schedule.reload.next_run_at }
      end
    end

    it 'avoids N+1 queries' do
      schedule.update!(next_run_at: 1.hour.ago)

      control_count = ActiveRecord::QueryRecorder.new { described_class.new.perform }.count

      schedule.update!(next_run_at: 1.hour.ago)
      schedule_2 = create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
      schedule_2.update!(next_run_at: 1.hour.ago)

      # +4 queries to update next_run_at for one additional schedule
      # +1 query to get the security policy configuration
      expect { described_class.new.perform }.not_to exceed_query_limit(control_count + 5)
    end

    context 'when another worker is still running' do
      let(:lease_key) { described_class::LEASE_KEY }
      let(:timeout) { described_class::LEASE_TIMEOUT }
      let(:lease) { Gitlab::ExclusiveLease.new(lease_key, timeout: timeout).try_obtain }

      it 'does not enqueue the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)
        expect(lease).not_to be_nil

        perform

        Gitlab::ExclusiveLease.cancel(lease_key, lease)
      end
    end

    context 'if cron is valid' do
      let(:cron) { '0 9 * * *' }

      before do
        schedule.update!(cron: cron)
      end

      shared_examples 'schedules' do
        specify do
          expect { perform }.to change { schedule.reload.next_run_at }
        end

        it 'enqueues the run worker' do
          expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
            .to receive(:perform_async).with(schedule.id, { 'branch' => 'main' })

          perform
        end

        specify do
          expect(Gitlab::AppJsonLogger).not_to receive(:info)
        end
      end

      context 'when daily' do
        let(:cron) { '0 9 * * *' }

        it_behaves_like 'schedules'
      end

      context 'when weekly' do
        let(:cron) { '30 10 * * 1,3,5' }

        it_behaves_like 'schedules'
      end

      context 'when monthly' do
        let(:cron) { '0 3 1,15,30 * *' }

        it_behaves_like 'schedules'
      end

      context 'and the schedule has branches' do
        let(:branches) { %w[main feature-branch non-existent-branch] }

        before do
          new_content = schedule.security_policy.content
          new_content['schedules'].first['branches'] = branches
          schedule.security_policy.update!(content: new_content)
        end

        it 'enqueues one worker for each branch' do
          branches.each do |branch|
            expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
              .to receive(:perform_async).with(schedule.id, { 'branch' => branch })
          end

          perform
        end
      end

      context 'when snoozed' do
        let(:cron) { '0 9 * * *' }

        before do
          schedule.update!(snoozed_until: Time.zone.now + 1.day)
        end

        it 'does not enqueue the run worker but still set next_run_at' do
          expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
            .not_to receive(:perform_async)

          expect { perform }.to change { schedule.reload.next_run_at }
        end

        it 'tracks the snoozed event', :clean_gitlab_redis_shared_state do
          expect { perform }
            .to trigger_internal_events('scheduled_pipeline_execution_policy_snoozed')
            .with(project: schedule.project, category: 'InternalEventTracking')
            .and increment_usage_metrics(
              # rubocop:disable Layout/LineLength -- Long metric names
              'redis_hll_counters.count_distinct_namespace_id_from_execute_job_scheduled_pipeline_execution_policy_snoozed_monthly'
              # rubocop:enable Layout/LineLength
            )
        end
      end
    end

    context 'if cron is invalid' do
      let_it_be_with_reload(:valid_schedule) do
        create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
      end

      before do
        schedule.cron = 'foobar'
        schedule.save!(validate: false)

        valid_schedule.update!(next_run_at: schedule.next_run_at)
      end

      it 'does not update next_run_at' do
        expect { perform }.not_to change { schedule.reload.next_run_at }
      end

      it 'does not enqueue the run worker for invalid schedules' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to(
          receive(:perform_async).with(schedule.id, anything)
        )

        perform
      end

      it 'enqueues the run worker for valid schedules' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).to(
          receive(:perform_async).with(valid_schedule.id, { 'branch' => 'main' })
        )

        perform
      end

      it 'logs the error' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          event: 'scheduled_scan_execution_policy_validation',
          message: 'Invalid cadence',
          project_id: schedule.project_id,
          cadence: schedule.cron
        )

        perform
      end
    end

    context 'when next_run_applied_delay is nil (old record without baked-in delay)' do
      before do
        schedule.update_columns(next_run_at: 1.hour.ago, next_run_applied_delay: nil)
      end

      it 'falls back to perform_in with a runtime-computed delay' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
          .to receive(:perform_in).with(kind_of(Integer), schedule.id, { 'branch' => 'main' })

        perform
      end

      it 'self-heals by persisting next_run_applied_delay after schedule_next_run!' do
        perform

        expect(schedule.reload.next_run_applied_delay).to be_a(Integer)
      end

      context 'when time_window_seconds exceeds the interval to next run' do
        before do
          schedule.update_columns(
            next_run_at: 1.day.ago, time_window_seconds: 2.days.to_i, cron: '0 0 * * *',
            next_run_applied_delay: nil
          )
        end

        it 'caps the delay to the time until next run' do
          travel_to(Time.zone.now.beginning_of_day + 1.hour) do
            # Random.rand is called once in the worker fallback path (with the
            # capped 23h value) and once in schedule_next_run! -> set_next_run_at
            expect(Random).to receive(:rand).with(23.hours.to_i).and_return(100).ordered
            expect(Random).to receive(:rand).with(kind_of(Integer)).and_return(100).ordered

            perform
          end
        end
      end
    end
  end

  describe 'metrics' do
    let(:histogram) do
      Security::SecurityOrchestrationPolicies::ObserveHistogramsService.histogram(described_class::HISTOGRAM)
    end

    specify do
      expect(histogram).to receive(:observe).with({}, kind_of(Float)).and_call_original

      perform
    end
  end
end
