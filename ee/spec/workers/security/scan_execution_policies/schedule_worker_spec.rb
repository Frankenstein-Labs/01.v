# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::ScheduleWorker, '#perform', feature_category: :security_policy_management do
  include ExclusiveLeaseHelpers

  let(:policy) do
    build(:scan_execution_policy, enabled: true,
      rules: [{ type: 'schedule', branch_type: 'default', cadence: '0 */6 * * *' }])
  end

  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }

  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:policy_configuration, freeze: false) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_refind(:rule_schedule) do
    create(:security_orchestration_policy_rule_schedule,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:policy_bot) { create(:user, :security_policy_bot) }

  let!(:project_schedule) do
    create(:security_scan_execution_project_schedule,
      policy_rule_schedule: rule_schedule,
      project: project,
      next_run_at: 1.minute.ago,
      next_run_applied_delay: 100)
  end

  subject(:perform) { described_class.new.perform }

  shared_examples 'skips execution but advances schedule' do
    it 'does not enqueue RunScheduleWorker' do
      expect(::Security::ScanExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)

      perform
    end

    it 'advances next_run_at so the schedule does not get stuck' do
      expect { perform }.to change { project_schedule.reload.next_run_at }.to(be_future)
    end
  end

  before do
    create(:project_member, user: policy_bot, project: project)
    stub_licensed_features(security_orchestration_policies: true)

    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end
  end

  it 'enqueues RunScheduleWorker for each branch' do
    expect(::Security::ScanExecutionPolicies::RunScheduleWorker).to receive(:perform_async)
      .with(project_schedule.id, { 'branch' => project.default_branch })

    perform
  end

  it 'advances the project schedule next_run_at' do
    expect { perform }.to change { project_schedule.reload.next_run_at }.to(be_future)
  end

  context 'when another worker is still running' do
    let(:lease_key) { described_class::LEASE_KEY }
    let(:timeout) { described_class::LEASE_TIMEOUT }

    before do
      stub_exclusive_lease_taken(lease_key, timeout: timeout)
    end

    it 'does not enqueue RunScheduleWorker' do
      expect(::Security::ScanExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)

      perform
    end

    it 'does not advance next_run_at' do
      expect { perform }.not_to change { project_schedule.reload.next_run_at }
    end
  end

  context 'when scan_execution_policy_per_project_scheduling feature flag is disabled' do
    before do
      stub_feature_flags(scan_execution_policy_per_project_scheduling: false)
    end

    it_behaves_like 'skips execution but advances schedule'
  end

  context 'when the cadence is invalid' do
    before do
      rule_schedule.update_column(:cron, '* * * * *')
    end

    it_behaves_like 'skips execution but advances schedule'

    it 'quarantines next_run_at far in the future instead of advancing via the invalid cron' do
      freeze_time do
        expect { perform }.to change { project_schedule.reload.next_run_at }
          .to(be_within(1.second).of(described_class::INVALID_CADENCE_QUARANTINE.from_now))
      end
    end

    it 'logs the invalid cadence' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(event: 'scheduled_scan_execution_policy_validation', project_id: project.id)
      )

      perform
    end
  end

  context 'when the project is marked for deletion' do
    before do
      project.update!(marked_for_deletion_at: Time.zone.now)
    end

    after do
      project.update!(marked_for_deletion_at: nil)
    end

    it_behaves_like 'skips execution but advances schedule'
  end

  context 'when security_orchestration_policies feature is not licensed' do
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it_behaves_like 'skips execution but advances schedule'
  end

  context 'when the policy is not found' do
    let(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy: [])
    end

    it_behaves_like 'skips execution but advances schedule'
  end

  context 'when there are no runnable per-project schedules' do
    before do
      project_schedule.update!(next_run_at: 1.hour.from_now)
    end

    it 'does not enqueue RunScheduleWorker' do
      expect(::Security::ScanExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)

      perform
    end
  end
end
