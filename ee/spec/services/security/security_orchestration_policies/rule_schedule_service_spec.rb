# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::RuleScheduleService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:project) { create(:project, :small_repo) }
    let(:current_user) { project.users.first }
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: policy_configuration) }
    let!(:scanner_profile) { create(:dast_scanner_profile, name: 'Scanner Profile', project: project) }
    let!(:site_profile) { create(:dast_site_profile, name: 'Site Profile', project: project) }
    let(:policy) { build(:scan_execution_policy, enabled: true, rules: [rule, pipeline_rule, other_schedule_rule]) }
    let(:pipeline_rule) { { type: 'pipeline', branches: ['develop'] } }
    let(:rule) { { type: 'schedule', branches: branches, cadence: '0 * * * *' } }
    let(:other_schedule_rule) { { type: 'schedule', branches: ['main'], cadence: '0 10 * * *' } }
    let(:branches) { %w[master production non-existing-branch] }
    let(:existing_branches) { %w[master production] }

    subject(:service) { described_class.new(project: project, current_user: current_user) }

    shared_examples 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker' do
      it 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker' do
        expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).not_to receive(:perform_async)
        expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).not_to receive(:perform_in)

        service.execute(schedule)
      end
    end

    shared_examples 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch' do
      it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch' do
        existing_branches.each do |branch|
          expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).to(
            receive(:perform_async)
              .with(project.id, current_user.id, schedule.id, branch)
              .and_call_original
          )
        end

        service.execute(schedule)
      end
    end

    before do
      stub_licensed_features(security_on_demand_scans: true)

      project.repository.create_branch('production', project.default_branch)

      allow_next_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
        allow(instance).to receive(:active_scan_execution_policies).and_return([policy])
      end
    end

    it 'returns a successful service response' do
      service_result = service.execute(schedule)

      expect(service_result).to be_kind_of(ServiceResponse)
      expect(service_result.success?).to be(true)
    end

    describe 'project schedule creation' do
      before do
        create(:security_policy, :scan_execution_policy,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: schedule.policy_index)
      end

      it 'creates a ScanExecutionProjectSchedule record' do
        expect { service.execute(schedule) }
          .to change { Security::ScanExecutionProjectSchedule.count }.by(1)

        project_schedule = Security::ScanExecutionProjectSchedule.last
        expect(project_schedule.project).to eq(project)
        expect(project_schedule.policy_rule_schedule).to eq(schedule)
        expect(project_schedule.next_run_applied_delay).to eq(0)
      end

      it 'logs the creation of a new project schedule' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          message: 'ScanExecutionProjectSchedule created via self-healing',
          project_id: project.id,
          rule_schedule_id: schedule.id
        ))

        service.execute(schedule)
      end

      it 'does not create duplicate records on subsequent executions' do
        service.execute(schedule)

        expect { service.execute(schedule) }.not_to change { Security::ScanExecutionProjectSchedule.count }
      end

      it 'does not log when the project schedule already exists' do
        service.execute(schedule)

        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        service.execute(schedule)
      end

      context 'when the Security::Policy record is missing' do
        before do
          Security::Policy.for_rule_schedule(schedule).delete_all
        end

        it 'logs a warning and does not create a project schedule' do
          expect(Gitlab::AppJsonLogger).to receive(:warn).with(hash_including(
            message: 'Security::Policy record not found for rule schedule, skipping project schedule creation',
            project_id: project.id,
            rule_schedule_id: schedule.id,
            policy_index: schedule.policy_index,
            security_orchestration_policy_configuration_id:
              schedule.security_orchestration_policy_configuration_id
          ))

          expect { service.execute(schedule) }.not_to change { Security::ScanExecutionProjectSchedule.count }
        end
      end

      context 'when the time_window is available' do
        before do
          policy[:rules].first.merge!({ time_window: { distribution: 'random', value: 3600 } })
        end

        it 'creates a record with a random delay within the time window' do
          expect { service.execute(schedule) }.to change { Security::ScanExecutionProjectSchedule.count }.by(1)

          project_schedule = Security::ScanExecutionProjectSchedule.last
          expect(project_schedule.next_run_applied_delay).to be_between(0, 3600)
        end

        it 'sets next_run_at relative to the rule_schedule next_run_at' do
          service.execute(schedule)

          project_schedule = Security::ScanExecutionProjectSchedule.last
          expect(project_schedule.next_run_at).to be_between(
            schedule.next_run_at,
            schedule.next_run_at + 3600.seconds
          )
        end

        it 'does not overwrite the existing delay on subsequent executions' do
          service.execute(schedule)
          project_schedule = Security::ScanExecutionProjectSchedule.last
          original_delay = project_schedule.next_run_applied_delay

          service.execute(schedule)

          expect(project_schedule.reload.next_run_applied_delay).to eq(original_delay)
        end

        context 'when the time_window exceeds the schedule interval' do
          # The schedule fires every hour (cron: '0 * * * *') but the
          # time_window is 2 hours (7200s). The effective window should be capped
          # to the time until the next scheduled run (4500s at 10:00 UTC because
          # the worker cron '*/15 * * * *' aligns 11:00 -> 11:15).
          let(:schedule) do
            create(:security_orchestration_policy_rule_schedule,
              security_orchestration_policy_configuration: policy_configuration,
              cron: '0 * * * *')
          end

          before do
            policy[:rules].first[:time_window][:value] = 7200
          end

          it 'caps the time_window to the schedule interval' do
            travel_to(Time.zone.parse('2024-06-15 10:00:00 UTC')) do
              # effective_time_window = min(7200, 4500) = 4500
              # Random.rand is called once for the project schedule delay and
              # once per branch for enqueue_pipelines (perform_in).
              expect(Random).to receive(:rand).with(4500).and_return(450)

              service.execute(schedule)

              project_schedule = Security::ScanExecutionProjectSchedule.last
              expect(project_schedule.next_run_applied_delay).to eq(450)
            end
          end
        end
      end

      context 'when project schedules are disabled' do
        before do
          stub_feature_flags(scan_execution_policy_project_schedule_creation: false)
        end

        it 'does not create ScanExecutionProjectSchedule records' do
          expect { service.execute(schedule) }
            .not_to change { Security::ScanExecutionProjectSchedule.count }
        end
      end
    end

    context 'when feature flag "scan_execution_policy_per_project_scheduling" is enabled' do
      # Pipelines are triggered by `ScanExecutionPolicies::ScheduleWorker`
      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
    end

    context 'when feature flag "scan_execution_policy_per_project_scheduling" is disabled' do
      before do
        stub_feature_flags(scan_execution_policy_per_project_scheduling: false)
      end

      context 'when time_window is configured' do
        before do
          policy[:rules].first.merge!({ time_window: { distribution: 'random', value: 3600 } })
        end

        it 'enqueues CreatePipelineWorker via perform_in with a random delay' do
          existing_branches.each do |branch|
            expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).to(
              receive(:perform_in)
                .with(a_value_between(0, 3600), project.id, current_user.id, schedule.id, branch)
                .and_call_original
            )
          end

          service.execute(schedule)
        end
      end

      context 'when scan type is dast' do
        before do
          policy[:actions] = [{ scan: 'dast' }]
        end

        it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
      end

      context 'when scan type is secret_detection' do
        before do
          policy[:actions] = [{ scan: 'secret_detection' }]
        end

        it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
      end

      context 'when scan type is container_scanning' do
        before do
          policy[:actions] = [{ scan: 'container_scanning' }]
        end

        context 'when clusters are not defined in the rule' do
          it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
        end

        context 'when agents are defined in the rule' do
          let(:rule) { { type: 'schedule', agents: { kasagent: { namespaces: 'default' } }, cadence: '*/20 * * * *' } }

          it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
        end
      end

      context 'when scan type is sast' do
        before do
          policy[:actions] = [{ scan: 'sast' }]
        end

        it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
      end

      context 'when policy actions exists and there are multiple matching branches' do
        it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
      end

      context 'when policy scan type is invalid' do
        let(:policy) { build(:scan_execution_policy, :with_schedule, enabled: true, actions: [{ scan: 'invalid' }]) }

        it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker' do
          expect(::Security::ScanExecutionPolicies::CreatePipelineWorker)
            .to(receive(:perform_async))
            .with(project.id, current_user.id, schedule.id, project.default_branch)
            .and_call_original

          service.execute(schedule)
        end
      end

      describe "branch lookup" do
        let(:policy) do
          build(
            :scan_execution_policy,
            enabled: true,
            rules: [{ type: 'schedule', branch_type: "protected", cadence: '*/20 * * * *' }]
          )
        end

        before do
          project.protected_branches.create!(name: project.default_branch)
        end

        it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker' do
          expect(::Security::ScanExecutionPolicies::CreatePipelineWorker)
            .to(receive(:perform_async))
            .with(project.id, current_user.id, schedule.id, project.default_branch)
            .and_call_original

          service.execute(schedule)
        end
      end

      context 'without rules' do
        before do
          policy.delete(:rules)
        end

        subject(:response) { service.execute(schedule) }

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'

        it 'fails' do
          expect(response.to_h).to include(status: :error, message: "No rules")
        end
      end

      context 'without scheduled rules' do
        before do
          policy[:rules] = [{ type: 'pipeline', branches: [] }]
        end

        subject(:response) { service.execute(schedule) }

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'

        it 'fails' do
          expect(response.to_h).to include(status: :error, message: "No scheduled rules")
        end
      end

      context 'with mismatching `branches`' do
        let(:policy) do
          build(
            :scan_execution_policy,
            enabled: true,
            rules: [{ type: 'schedule', branches: %w[invalid_branch], cadence: '*/20 * * * *' }]
          )
        end

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
      end

      context 'with mismatching `branch_type`' do
        let(:policy) do
          build(
            :scan_execution_policy,
            enabled: true,
            rules: [{ type: 'schedule', branch_type: "protected", cadence: '*/20 * * * *' }]
          )
        end

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
      end

      context 'when policy actions does not exist' do
        let(:policy) { build(:scan_execution_policy, :with_schedule, enabled: true, actions: []) }

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
      end

      context 'when policy does not exist' do
        let(:policy) { nil }

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
      end
    end
  end
end
