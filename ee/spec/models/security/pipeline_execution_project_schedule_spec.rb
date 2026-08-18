# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionProjectSchedule, feature_category: :security_policy_management do
  describe 'validations' do
    let(:schedule) { build(:security_pipeline_execution_project_schedule) }

    subject { schedule }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:cron) }
    it { is_expected.to validate_presence_of(:cron_timezone) }
    it { is_expected.to validate_presence_of(:time_window_seconds) }

    it 'validates time_window_seconds limits' do
      is_expected.to(
        validate_numericality_of(:time_window_seconds)
          .is_greater_than_or_equal_to(10.minutes.to_i)
          .is_less_than_or_equal_to(Security::PipelineExecutionProjectSchedule::MAX_TIME_WINDOW.to_i)
          .only_integer
      )
    end

    context 'when security policy is not a pipeline_execution_schedule_policy' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_policy) }
      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      it { is_expected.not_to be_valid }
    end

    describe 'cron validation' do
      context 'with valid crontab' do
        before do
          schedule.cron = "* * * * *"
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid crontab' do
        before do
          schedule.cron = "a b c d e"
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'cron timezone validation' do
      context 'with valid cron_timezone' do
        before do
          schedule.cron_timezone = "Europe/Berlin"
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid cron_timezone' do
        before do
          schedule.cron_timezone = "Europe/New_York"
        end

        it { is_expected.to be_invalid }
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
  end

  describe 'scopes' do
    describe '.for_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule, project: project) }
      let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule) }

      it 'returns schedules for the given project' do
        expect(described_class.for_project(project)).to contain_exactly(schedule)
      end
    end

    describe '.runnable_schedules' do
      let_it_be_with_reload(:runnable_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be_with_reload(:future_schedule) { create(:security_pipeline_execution_project_schedule) }

      before do
        runnable_schedule.update!(next_run_at: 1.hour.ago)
        future_schedule.update!(next_run_at: 1.hour.from_now)
      end

      it 'returns schedules that are due to run' do
        expect(described_class.runnable_schedules).to contain_exactly(runnable_schedule)
      end
    end

    describe '.ordered_by_next_run_at' do
      let_it_be_with_reload(:monthly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be_with_reload(:weekly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be_with_reload(:daily_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be_with_reload(:daily_schedule_2) { create(:security_pipeline_execution_project_schedule) }

      before do
        monthly_schedule.update!(next_run_at: Time.zone.now + 1.month)
        weekly_schedule.update!(next_run_at: Time.zone.now + 1.week)

        # Use the same time for both records to ensure the order by id is correct.
        daily_schedule_time = Time.zone.now + 1.day
        daily_schedule.update!(next_run_at: daily_schedule_time)
        daily_schedule_2.update!(next_run_at: daily_schedule_time)
      end

      it 'returns schedules ordered by next_run_at and id' do
        expect(described_class.ordered_by_next_run_at).to eq(
          [daily_schedule, daily_schedule_2, weekly_schedule, monthly_schedule]
        )
      end
    end

    describe '.including_security_policy_and_project' do
      let_it_be(:schedule_1) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:schedule_2) { create(:security_pipeline_execution_project_schedule) }

      it 'preloads security_policy and project' do
        recorder = ActiveRecord::QueryRecorder.new do
          schedules = described_class.including_security_policy_and_project

          schedules.each do |schedule|
            schedule.security_policy
            schedule.project
          end
        end

        # 1. Load schedules
        # 2. Load security_policy
        # 3. Load project
        expect(recorder.count).to eq(3)
      end
    end

    describe '.for_policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:schedule) do
        create(:security_pipeline_execution_project_schedule, security_policy: policy)
      end

      let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule) }

      it 'returns schedules for the given policy' do
        expect(described_class.for_policy(policy)).to contain_exactly(schedule)
      end
    end
  end

  describe 'callbacks' do
    describe 'update next_run_at on create', time_travel_to: '2024-12-20 00:00:00' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:schedule) do
        build(
          :security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          cron: "0 0 * * *",
          time_window_seconds: 3600)
      end

      subject(:save!) { schedule.save! }

      it 'sets next_run_at to at least the next cron time' do
        allow(Random).to receive(:rand).and_return(0)

        save!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end

      it 'bakes random offset into next_run_at within effective_time_window' do
        save!

        base_cron_time = Time.zone.now + 1.day

        expect(schedule.next_run_at).to be >= base_cron_time
        expect(schedule.next_run_at).to be <= base_cron_time + 3600.seconds
      end

      it 'persists next_run_applied_delay' do
        save!

        expect(schedule.next_run_applied_delay).to be_a(Integer)
        expect(schedule.next_run_applied_delay).to be >= 0
        expect(schedule.next_run_applied_delay).to be <= 3600
      end
    end
  end

  context 'with cron schedulable with delay' do
    let(:schedule) { create(:security_pipeline_execution_project_schedule) }

    it_behaves_like 'cron schedulable with delay'
  end

  describe '#ci_content' do
    subject(:ci_content) { build(:security_pipeline_execution_project_schedule).ci_content }

    it 'returns the security policy CI config content' do
      expect(ci_content).to eq(
        'include' => [{ 'project' => 'compliance-project', 'file' => 'compliance-pipeline.yml' }])
    end
  end

  describe '#snoozed?' do
    subject(:snoozed?) { schedule.snoozed? }

    context 'when snoozed_until is nil' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: nil) }

      it { is_expected.to be(false) }
    end

    context 'when snoozed_until is in the future' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: 1.day.from_now) }

      it { is_expected.to be(true) }
    end

    context 'when snoozed_until is in the past' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: 1.day.ago) }

      it { is_expected.to be(false) }
    end
  end

  describe '#policy_management_project' do
    let_it_be(:policy_management_project) { create(:project) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project)
    end

    let_it_be(:security_policy) do
      create(:security_policy, :pipeline_execution_schedule_policy,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:schedule) do
      create(:security_pipeline_execution_project_schedule, security_policy: security_policy)
    end

    subject(:policy_management_project_result) { schedule.policy_management_project }

    it { is_expected.to eq(policy_management_project) }

    context 'when security_policy association does not exist' do
      it 'returns nil when security_policy is nil' do
        allow(schedule).to receive(:security_policy).and_return(nil)

        expect(policy_management_project_result).to be_nil
      end
    end
  end

  describe '#branches' do
    let_it_be(:project) { create(:project, :repository) }

    let(:security_policy) { build(:security_policy, :pipeline_execution_schedule_policy) }
    let(:schedule) do
      build(:security_pipeline_execution_project_schedule, security_policy: security_policy, project: project)
    end

    subject(:branches) { schedule.branches }

    it { is_expected.to eq(['master']) }

    context 'when security policy content has branches' do
      let(:security_policy) { build(:security_policy, :pipeline_execution_schedule_policy, content: policy_content) }
      let(:branches_content) { %w[branch-1 branch-2] }

      let(:policy_content) do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedules: [
            { type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' },
              branches: branches_content }
          ]
        }
      end

      it { is_expected.to eq(branches_content) }

      context 'when the same branch is used twice' do
        let(:branches_content) { %w[branch-1 branch-1] }

        it { is_expected.to eq(%w[branch-1]) }
      end
    end
  end
end
