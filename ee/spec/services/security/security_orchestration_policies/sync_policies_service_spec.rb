# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncPoliciesService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_refind(:configuration) do
    create(:security_orchestration_policy_configuration, configured_at: nil, project: project)
  end

  let_it_be(:schedule) do
    create(
      :security_orchestration_policy_rule_schedule,
      security_orchestration_policy_configuration: configuration,
      owner: project.owner
    )
  end

  before do
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(active_policies.to_yaml)
      allow(repository).to receive(:last_commit_for_path)
    end

    allow(configuration).to receive(:policy_last_updated_by).and_return(project.owner)
  end

  describe '#execute' do
    let(:force_resync) { false }

    subject(:execute) do
      described_class.new(configuration: configuration, params: { force_resync: force_resync }).execute
    end

    context 'when policy is valid' do
      let(:rules) do
        [{ type: 'schedule', branches: %w[production], cadence: '*/20 * * * *' }]
      end

      let(:active_policies) do
        {
          experiments: policy_experiments,
          scan_execution_policy: [
            {
              name: 'Scheduled DAST 1',
              description: 'This policy runs DAST for every 20 mins',
              enabled: true,
              rules: rules,
              actions: [
                { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }
              ],
              type: 'scan_execution_policy',
              policy_index: 0
            },
            {
              name: 'Scheduled DAST 2',
              description: 'This policy runs DAST for every 20 mins',
              enabled: true,
              rules: rules,
              actions: [
                { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }
              ],
              type: 'scan_execution_policy',
              policy_index: 1
            }
          ]
        }
      end

      let(:policy_experiments) do
        {
          'test_feature' => {
            'enabled' => true,
            'configuration' => { 'option' => 'value' }
          }
        }
      end

      it 'updates configuration.configured_at to the current time', :freeze_time do
        expect { execute }.to change { configuration.reload.configured_at }.from(nil).to(Time.current)
      end

      # This spec ensures that `configured_at` is updated before enqueuing the `PersistSecurityPoliciesWorker`
      # as we fetch the `latest_commit_before_configured_at` inside `CollectPoliciesAuditEvents`.
      it 'updates the configuration.configured_at before enqueuing PersistSecurityPoliciesWorker', :freeze_time do
        expect(configuration).to receive(:update!).with(experiments: anything).ordered.and_call_original

        expect(configuration).to receive(:update!)
          .with(configured_at: Time.current)
          .ordered
          .and_call_original

        expect(Security::PersistSecurityPoliciesWorker).to receive(:perform_async)
          .with(configuration.id, { 'force_resync' => false })
          .ordered
          .and_call_original

        execute
      end

      it 'executes ProcessRuleService for each policy' do
        active_policies[:scan_execution_policy].each_with_index do |policy, policy_index|
          expect_next_instance_of(
            Security::SecurityOrchestrationPolicies::ProcessRuleService,
            policy_configuration: configuration,
            policy_index: policy_index, policy: policy
          ) do |service|
            expect(service).to receive(:execute)
          end
        end

        execute
      end

      it 'invalidates the policy yaml cache' do
        expect(configuration).to receive(:invalidate_policy_yaml_cache)

        execute
      end

      it 'persists experiments from policy' do
        expect { execute }.to change { configuration.reload.experiments }.from({}).to(policy_experiments)
      end

      context 'when policy has no experiments' do
        let(:policy_experiments) { nil }

        it 'does not invoke Security::SecurityOrchestrationPolicies::UpdateExperimentsService' do
          expect(Security::SecurityOrchestrationPolicies::UpdateExperimentsService).not_to receive(:new)

          execute
        end
      end

      describe "policy persistence" do
        let(:persistence_worker) { Security::PersistSecurityPoliciesWorker }

        shared_examples "persist policies" do
          context 'when policies_changed? is false' do
            before do
              allow(configuration).to receive(:policies_changed?).and_return(false)
            end

            it 'does not persist policies' do
              expect(persistence_worker).not_to receive(:perform_async).with(configuration.id,
                { 'force_resync' => false })

              execute
            end

            it 'does not process policy', :aggregate_failures do
              expect(Security::SecurityOrchestrationPolicies::ProcessRuleService).not_to receive(:new)
              expect(Security::SecurityOrchestrationPolicies::ComplianceFrameworks::SyncService).not_to receive(:new)

              expect { execute }.to not_change(Security::OrchestrationPolicyRuleSchedule, :count)
            end

            it 'updates configuration.configured_at to the current time', :freeze_time do
              expect { execute }.to change { configuration.reload.configured_at }.from(nil).to(Time.current)
            end

            context 'when force_resync is true' do
              let(:force_resync) { true }

              it 'persists policies' do
                expect(persistence_worker).to receive(:perform_async).with(configuration.id, { 'force_resync' => true })

                execute
              end
            end
          end

          context 'when policies_changed? is true' do
            before do
              allow(configuration).to receive(:policies_changed?).and_return(true)
            end

            it 'persists policies' do
              expect(persistence_worker).to receive(:perform_async).with(configuration.id, { 'force_resync' => false })

              execute
            end
          end
        end

        context "with project-level configuration" do
          include_examples "persist policies"
        end

        context "with group-level configuration" do
          let_it_be(:group) { create(:group) }

          before do
            configuration.update!(project_id: nil, namespace_id: group.id)
          end

          include_examples "persist policies"
        end
      end

      shared_examples 'creates new rule schedules' do |expected_schedules:|
        it 'creates a rule schedule for each schedule rule in the scan execution policies' do
          expect { execute }.to change { Security::OrchestrationPolicyRuleSchedule.count }
            .from(1).to(expected_schedules)
        end

        it 'deletes existing rule schedules', :freeze_time do
          execute

          Security::OrchestrationPolicyRuleSchedule.all.find_each do |rule_schedule|
            expect(rule_schedule.created_at).to eq(Time.current)
          end
        end
      end

      context 'with one schedule rule per policy' do
        include_examples 'creates new rule schedules', expected_schedules: 2
      end

      context 'with multiple schedule rules per policy' do
        let(:rules) do
          [
            { type: 'schedule', branches: %w[production], cadence: '*/20 * * * *' },
            { type: 'schedule', branches: %w[staging], cadence: '*/20 * * * *' }
          ]
        end

        include_examples 'creates new rule schedules', expected_schedules: 4 # 2 policies * 2 rules
      end
    end

    context 'when policy is invalid' do
      let(:active_policies) do
        {
          scan_execution_policy: [
            {
              key: 'invalid',
              label: 'invalid'
            }
          ]
        }
      end

      it 'does not execute process for any policy', :aggregate_failures do
        expect(Security::SecurityOrchestrationPolicies::ProcessRuleService).not_to receive(:new)

        expect { execute }.to change { Security::OrchestrationPolicyRuleSchedule.count }.by(-1)
        expect(configuration.reload.configured_at).to be_like_time(Time.current)
      end

      describe 'auditing invalid policy yaml' do
        let(:audit_service) do
          Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService.new(
            configuration
          )
        end

        before do
          allow(Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService)
          .to receive(:new).with(configuration).and_return(audit_service)
        end

        it 'audits the invalid policy yaml' do
          expect(audit_service).to receive(:execute)

          execute
        end

        context 'when there is an error' do
          before do
            allow(audit_service).to receive(:execute).and_raise(StandardError)
            allow(Gitlab::ErrorTracking).to receive(:track_exception).and_call_original
          end

          it 'tracks the error and proceeds', :aggregate_failures do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              an_instance_of(StandardError),
              security_policy_management_project_id: configuration.security_policy_management_project.id,
              configuration_id: configuration.id
            )

            expect { execute }.not_to raise_error
          end
        end

        context 'when policy project is linked to multiple projects' do
          let_it_be(:policy_project) { create(:project) }
          let_it_be_with_reload(:policy_configuration) do
            create(:security_orchestration_policy_configuration,
              created_at: 5.minutes.ago,
              security_policy_management_project: policy_project)
          end

          let_it_be_with_reload(:another_policy_configuration) do
            create(:security_orchestration_policy_configuration,
              created_at: 10.minutes.ago,
              security_policy_management_project: policy_project)
          end

          subject(:execute) do
            described_class.new(configuration: policy_configuration).execute
            described_class.new(configuration: another_policy_configuration).execute
          end

          it 'collects invalid policy yaml event for the first policy configuration only' do
            expect(Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService)
              .to receive(:new).once.with(another_policy_configuration)

            expect(Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService)
              .not_to receive(:new).with(policy_configuration)

            execute
          end
        end
      end

      context 'with existing policy reads' do
        let_it_be(:policy_read) do
          create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration)
        end

        it 'deletes existing policy reads', :sidekiq_inline do
          expect { execute }.to change { Security::ScanResultPolicyRead.exists?(policy_read.id) }.from(true).to(false)
        end
      end
    end
  end
end
