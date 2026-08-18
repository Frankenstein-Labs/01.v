# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionProjectSchedule, feature_category: :security_policy_management do
  let_it_be(:project, freeze: true) { create(:project) }

  describe 'validations' do
    let(:schedule) { build(:security_scan_execution_project_schedule) }

    subject { schedule }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:policy_rule_schedule) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:next_run_at) }

    describe 'uniqueness' do
      subject { create(:security_scan_execution_project_schedule) }

      it { is_expected.to validate_uniqueness_of(:policy_rule_schedule_id).scoped_to(:project_id) }
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:policy_rule_schedule).class_name('Security::OrchestrationPolicyRuleSchedule') }
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
  end

  describe '.create_if_not_exists' do
    let_it_be(:policy_rule_schedule) { create(:security_orchestration_policy_rule_schedule) }
    let_it_be(:security_policy) { create(:security_policy, :scan_execution_policy) }

    let(:next_run_at) { 1.day.from_now.change(usec: 0) }
    let(:next_run_applied_delay) { 5 }

    subject(:create_if_not_exists) do
      described_class.create_if_not_exists(
        policy_rule_schedule: policy_rule_schedule,
        project: project,
        security_policy: security_policy,
        next_run_at: next_run_at,
        next_run_applied_delay: next_run_applied_delay
      )
    end

    context 'when no matching record exists' do
      it 'returns true' do
        expect(create_if_not_exists).to be true
      end

      it 'creates a new record with correct attributes' do
        expect { create_if_not_exists }.to change { described_class.count }.by(1)

        record = described_class.last
        expect(record).to have_attributes(
          policy_rule_schedule_id: policy_rule_schedule.id,
          project_id: project.id,
          security_policy_id: security_policy.id,
          next_run_at: be_within(5.seconds).of(next_run_at),
          next_run_applied_delay: next_run_applied_delay
        )
      end
    end

    context 'when a record with the same policy_rule_schedule and project already exists' do
      before do
        create(:security_scan_execution_project_schedule,
          policy_rule_schedule: policy_rule_schedule,
          project: project,
          security_policy: security_policy
        )
      end

      it 'returns false' do
        expect(create_if_not_exists).to be false
      end

      it 'does not create a new record' do
        expect { create_if_not_exists }.not_to change { described_class.count }
      end
    end
  end

  describe 'scopes' do
    describe '.runnable_schedules' do
      let_it_be(:runnable_schedule) { create(:security_scan_execution_project_schedule, next_run_at: 1.hour.ago) }
      let_it_be(:future_schedule) { create(:security_scan_execution_project_schedule, next_run_at: 1.hour.from_now) }

      it 'returns schedules that are due to run' do
        expect(described_class.runnable_schedules).to contain_exactly(runnable_schedule)
      end
    end

    describe '.for_project' do
      let_it_be(:schedule) { create(:security_scan_execution_project_schedule, project: project) }
      let_it_be(:other_schedule) { create(:security_scan_execution_project_schedule) }

      subject(:schedules_for_project) { described_class.for_project(project) }

      it 'returns schedules for the given project' do
        expect(schedules_for_project).to contain_exactly(schedule)
      end
    end

    describe '.for_security_policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }
      let_it_be(:schedule) { create(:security_scan_execution_project_schedule, security_policy: policy) }
      let_it_be(:other_schedule) { create(:security_scan_execution_project_schedule) }

      it 'returns schedules for the given security policy' do
        expect(described_class.for_security_policy(policy.id)).to contain_exactly(schedule)
      end
    end

    describe '.for_rule_schedules' do
      let_it_be(:rule_schedule) { create(:security_orchestration_policy_rule_schedule) }
      let_it_be(:schedule) do
        create(:security_scan_execution_project_schedule, policy_rule_schedule: rule_schedule)
      end

      let_it_be(:other_schedule) { create(:security_scan_execution_project_schedule) }

      it 'returns schedules for the given rule schedule ids' do
        expect(described_class.for_rule_schedules([rule_schedule.id])).to contain_exactly(schedule)
      end
    end

    describe '.ordered_by_next_run_at' do
      let_it_be(:schedule_1) { create(:security_scan_execution_project_schedule, next_run_at: 2.hours.from_now) }
      let_it_be(:schedule_2) { create(:security_scan_execution_project_schedule, next_run_at: 1.hour.from_now) }
      let_it_be(:schedule_3) { create(:security_scan_execution_project_schedule, next_run_at: 3.hours.from_now) }

      it 'returns schedules ordered by next_run_at ascending' do
        expect(described_class.ordered_by_next_run_at).to eq([schedule_2, schedule_1, schedule_3])
      end
    end
  end

  describe 'delegation' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_rule_schedule) do
      create(:security_orchestration_policy_rule_schedule,
        security_orchestration_policy_configuration: policy_configuration,
        cron: '0 8 * * *')
    end

    let(:schedule) { build(:security_scan_execution_project_schedule, policy_rule_schedule: policy_rule_schedule) }

    describe '#time_window' do
      it 'delegates to policy_rule_schedule' do
        expect(schedule.time_window).to eq(policy_rule_schedule.time_window)
      end
    end

    describe '#cron' do
      it 'delegates to policy_rule_schedule' do
        expect(schedule.cron).to eq('0 8 * * *')
      end
    end

    describe '#cron_timezone' do
      it 'delegates to policy_rule_schedule' do
        expect(schedule.cron_timezone).to eq(policy_rule_schedule.cron_timezone)
      end
    end

    describe '#time_window_seconds' do
      it 'is an alias for time_window' do
        allow(policy_rule_schedule).to receive(:time_window).and_return(3600)
        expect(schedule.time_window_seconds).to eq(3600)
      end
    end
  end

  context 'with cron schedulable with delay' do
    let(:schedule) { create(:security_scan_execution_project_schedule) }

    it_behaves_like 'cron schedulable with delay'
  end
end
