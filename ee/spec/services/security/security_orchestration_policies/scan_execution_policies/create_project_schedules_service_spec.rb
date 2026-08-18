# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ScanExecutionPolicies::CreateProjectSchedulesService,
  feature_category: :security_policy_management do
  let_it_be(:project, freeze: true) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, :scan_execution_policy,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: 0)
  end

  let_it_be_with_refind(:rule_schedule) do
    create(:security_orchestration_policy_rule_schedule,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: 0,
      rule_index: 0)
  end

  describe '#execute', :aggregate_failures do
    subject(:execute) { described_class.new(project: project, security_policy: security_policy).execute }

    it 'creates a ScanExecutionProjectSchedule for each rule schedule' do
      expect { execute }.to change { Security::ScanExecutionProjectSchedule.count }.by(1)

      schedule = Security::ScanExecutionProjectSchedule.last
      expect(schedule.policy_rule_schedule).to eq(rule_schedule)
      expect(schedule.project).to eq(project)
      expect(schedule.security_policy).to eq(security_policy)
      expect(schedule.next_run_at).to be_present
    end

    context 'when there are multiple rule schedules for the policy' do
      let_it_be(:second_rule_schedule) do
        create(:security_orchestration_policy_rule_schedule,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: 0,
          rule_index: 1)
      end

      it 'creates a project schedule for each rule schedule' do
        expect { execute }.to change { Security::ScanExecutionProjectSchedule.count }.by(2)
      end
    end

    context 'when project schedules already exist' do
      let_it_be(:existing_schedule) do
        create(:security_scan_execution_project_schedule,
          policy_rule_schedule: rule_schedule,
          project: project,
          security_policy: security_policy,
          next_run_at: 1.hour.ago)
      end

      it 'deletes existing schedules and creates new ones' do
        expect { execute }.not_to change { Security::ScanExecutionProjectSchedule.count }

        expect(Security::ScanExecutionProjectSchedule.find_by(id: existing_schedule.id)).to be_nil

        new_schedule = Security::ScanExecutionProjectSchedule.last
        expect(new_schedule.policy_rule_schedule).to eq(rule_schedule)
        expect(new_schedule.next_run_at).not_to eq(existing_schedule.next_run_at)
      end
    end

    context 'when schedules belong to a different policy' do
      let_it_be(:other_rule_schedule) do
        create(:security_orchestration_policy_rule_schedule,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: 1,
          rule_index: 0)
      end

      let_it_be(:other_schedule) do
        create(:security_scan_execution_project_schedule,
          policy_rule_schedule: other_rule_schedule,
          project: project,
          security_policy: security_policy)
      end

      it 'does not delete schedules belonging to other policies' do
        expect { execute }.not_to change { other_schedule.reload.persisted? }.from(true)
      end
    end

    context 'when schedules belong to a different project' do
      let_it_be(:other_project) { create(:project) }

      let_it_be(:other_project_schedule) do
        create(:security_scan_execution_project_schedule,
          policy_rule_schedule: rule_schedule,
          project: other_project,
          security_policy: security_policy)
      end

      it 'does not delete schedules belonging to other projects' do
        expect { execute }.not_to change { other_project_schedule.reload.persisted? }.from(true)
      end
    end

    context 'when rule schedule has a positive time_window configured' do
      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyRuleSchedule) do |instance|
          allow(instance).to receive(:effective_time_window).and_return(3600)
        end
      end

      it 'creates a project schedule with a random delay within the time window' do
        expect { execute }.to change { Security::ScanExecutionProjectSchedule.count }.by(1)

        schedule = Security::ScanExecutionProjectSchedule.last
        expect(schedule.next_run_applied_delay).to be_between(0, 3600)
        expect(schedule.next_run_at).to be >= rule_schedule.next_run_at
      end
    end

    context 'when rule schedule has no time_window configured' do
      it 'creates a project schedule with zero delay' do
        expect { execute }.to change { Security::ScanExecutionProjectSchedule.count }.by(1)

        schedule = Security::ScanExecutionProjectSchedule.last
        expect(schedule.next_run_applied_delay).to eq(0)
        expect(schedule.next_run_at).to eq(rule_schedule.next_run_at)
      end
    end

    context 'when rule schedule has nil next_run_at' do
      let(:original_next_run_at) { rule_schedule.next_run_at }

      before do
        rule_schedule.update_column(:next_run_at, nil)
      end

      after do
        rule_schedule.update_column(:next_run_at, original_next_run_at)
      end

      it 'skips the schedule and does not create project schedules' do
        expect { execute }.not_to change { Security::ScanExecutionProjectSchedule.count }
      end
    end

    context 'when no rule schedules exist for the policy' do
      before do
        rule_schedule.destroy!
      end

      it 'does not create any project schedules' do
        expect { execute }.not_to change { Security::ScanExecutionProjectSchedule.count }
      end
    end

    context 'when scan_execution_policy_project_schedule_creation feature flag is disabled' do
      before do
        stub_feature_flags(scan_execution_policy_project_schedule_creation: false)
      end

      it 'does not create any project schedules' do
        expect { execute }.not_to change { Security::ScanExecutionProjectSchedule.count }
      end
    end

    context 'when schedule creation fails' do
      let(:exception_message) { 'something went wrong' }

      let(:expected_log) do
        {
          "class" => described_class.name,
          "event" => described_class::EVENT_KEY,
          "exception_class" => StandardError.name,
          "exception_message" => exception_message,
          "project_id" => project.id,
          "policy_id" => security_policy.id
        }
      end

      before do
        allow(Security::ScanExecutionProjectSchedule).to receive(:insert_all)
          .and_raise(StandardError, exception_message)
      end

      it 'logs and reraises the error', :aggregate_failures do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

        expect { execute }.to raise_error(StandardError, exception_message)
      end
    end
  end
end
