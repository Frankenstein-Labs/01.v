# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::RunScheduleWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be_with_reload(:project) { create(:project, :small_repo) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:rule_schedule) do
      create(:security_orchestration_policy_rule_schedule,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:policy_bot) { create(:user, :security_policy_bot) }

    let_it_be(:project_schedule) do
      create(:security_scan_execution_project_schedule,
        policy_rule_schedule: rule_schedule,
        project: project,
        next_run_at: 1.minute.ago,
        next_run_applied_delay: 100)
    end

    let(:policy) { build(:scan_execution_policy, enabled: true, actions: [{ scan: 'dast' }]) }
    let(:options) { { 'branch' => 'main' } }

    subject(:perform) { described_class.new.perform(project_schedule.id, options) }

    before_all do
      create(:project_member, user: policy_bot, project: project)
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)

      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
        allow(instance).to receive(:active_scan_execution_policies).and_return([policy])
      end
    end

    shared_examples_for 'does not create a pipeline' do
      specify do
        expect(Security::SecurityOrchestrationPolicies::CreatePipelineService).not_to receive(:new)

        perform
      end
    end

    it 'delegates pipeline creation to CreatePipelineService' do
      expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
        receive(:new)
          .with(project: project, current_user: policy_bot,
            params: { actions: [{ scan: 'dast' }], branch: 'main', policy_name: policy[:name] })
          .and_call_original)

      perform
    end

    it 'tracks the internal event' do
      expect { perform }.to trigger_internal_events('enforce_scheduled_scan_execution_policy_in_project')
        .with(project: project, additional_properties: { value: 1, label: anything,
                                                         property: rule_schedule.policy_source,
                                                         time_window: 0 })
    end

    context 'when the schedule defines a time_window' do
      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyRuleSchedule) do |instance|
          allow(instance).to receive(:time_window).and_return(3600)
        end
      end

      it 'tracks time_window as 1' do
        expect { perform }.to trigger_internal_events('enforce_scheduled_scan_execution_policy_in_project')
          .with(project: project, additional_properties: { value: 1, label: anything,
                                                           property: anything,
                                                           time_window: 1 })
      end
    end

    context 'when project schedule does not exist' do
      subject(:perform) { described_class.new.perform(non_existing_record_id, options) }

      it_behaves_like 'does not create a pipeline'
    end

    context 'when scan_execution_policy_per_project_scheduling feature flag is disabled' do
      before do
        stub_feature_flags(scan_execution_policy_per_project_scheduling: false)
      end

      it_behaves_like 'does not create a pipeline'
    end

    context 'when the project is marked for deletion' do
      before do
        project.update!(marked_for_deletion_at: Time.zone.now)
      end

      after do
        project.update!(marked_for_deletion_at: nil)
      end

      it_behaves_like 'does not create a pipeline'
    end

    context 'when security_orchestration_policies feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it_behaves_like 'does not create a pipeline'
    end

    context 'when the security policy bot is missing' do
      before do
        project.security_policy_bot.destroy!
      end

      it 'creates a new bot user' do
        expect { perform }.to change { project.reload.security_policy_bot }.from(nil).to(User)
      end

      it 'proceeds with pipeline creation' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService)
          .to receive(:new).and_call_original

        perform
      end
    end

    context 'when no branch is provided in options' do
      let(:options) { {} }

      it 'falls back to the default branch' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
          receive(:new)
            .with(project: project, current_user: policy_bot,
              params: { actions: [{ scan: 'dast' }], branch: project.default_branch_or_main,
                        policy_name: policy[:name] })
            .and_call_original)

        perform
      end
    end

    context 'when options is nil' do
      let(:options) { nil }

      it 'does not raise an error and falls back to the default branch' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
          receive(:new)
            .with(project: project, current_user: policy_bot,
              params: { actions: [{ scan: 'dast' }], branch: project.default_branch_or_main,
                        policy_name: policy[:name] })
            .and_call_original)

        perform
      end
    end

    context 'when options is not a hash' do
      it 'raises an error' do
        expect { described_class.new.perform(project_schedule.id, 1) }
          .to raise_error(ArgumentError, 'options must be of type Hash')
      end
    end

    context 'when the policy has no actions' do
      let(:policy) { build(:scan_execution_policy, enabled: true, actions: []) }

      it_behaves_like 'does not create a pipeline'
    end

    context 'when the policy is blank' do
      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
          allow(instance).to receive(:active_scan_execution_policies).and_return([])
        end
      end

      it_behaves_like 'does not create a pipeline'
    end

    context 'when bot user creation fails' do
      before do
        project.security_policy_bot.destroy!
        allow(Security::Orchestration::CreateBotService).to receive(:new).and_return(
          instance_double(Security::Orchestration::CreateBotService, execute: nil)
        )
      end

      it_behaves_like 'does not create a pipeline'
    end

    describe 'action limit' do
      let(:actions) { [{ scan: 'sast' }, { scan: 'dast' }, { scan: 'secret_detection' }] }
      let(:policy) { build(:scan_execution_policy, enabled: true, actions: actions) }
      let(:action_limit) { 2 }

      before do
        allow(Gitlab::CurrentSettings).to receive(:scan_execution_policies_action_limit).and_return(action_limit)
      end

      it 'limits the number of actions' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
          receive(:new)
            .with(project: project, current_user: policy_bot,
              params: { actions: actions.first(action_limit), branch: 'main', policy_name: policy[:name] })
            .and_call_original)

        perform
      end

      context 'when the limit is zero' do
        let(:action_limit) { 0 }

        it 'does not limit the number of actions' do
          expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
            receive(:new)
              .with(project: project, current_user: policy_bot,
                params: { actions: actions, branch: 'main', policy_name: policy[:name] })
              .and_call_original)

          perform
        end
      end
    end

    context 'when CreatePipelineService succeeds' do
      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::CreatePipelineService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      it 'does not log an error or enqueue audit worker' do
        expect(::Gitlab::AppJsonLogger).not_to receive(:warn)
        expect(::Security::Policies::ScheduledScansNotEnforcedAuditWorker).not_to receive(:perform_async)

        perform
      end
    end

    context 'when CreatePipelineService returns an error' do
      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::CreatePipelineService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'pipeline error'))
        end
      end

      it 'logs the error' do
        expect(::Gitlab::AppJsonLogger).to receive(:warn).with(hash_including(
          'message' => 'pipeline error',
          'project_id' => project.id,
          'security_orchestration_policy_configuration_id' => policy_configuration.id,
          'rule_schedule_id' => rule_schedule.id,
          'branch' => 'main'
        ))

        perform
      end

      it 'enqueues ScheduledScansNotEnforcedAuditWorker' do
        expect(::Security::Policies::ScheduledScansNotEnforcedAuditWorker)
          .to receive(:perform_async)
          .with(project.id, policy_bot.id, rule_schedule.id, 'main')

        perform
      end

      it 'still tracks the internal event' do
        expect { perform }.to trigger_internal_events('enforce_scheduled_scan_execution_policy_in_project')
          .with(project: project, additional_properties: { value: 1, label: 'error',
                                                           property: anything,
                                                           time_window: 0 })
      end
    end
  end
end
