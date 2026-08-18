# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Orchestration::UnassignService, :sidekiq_inline, feature_category: :security_policy_management do
  describe '#execute' do
    subject(:result) { service.execute }

    let_it_be(:current_user) { create(:user) }

    shared_examples 'unassigns policy project' do
      context 'when policy project is assigned to a project or namespace' do
        let(:service) { described_class.new(container: container, current_user: current_user) }

        let_it_be(:rule_schedule) do
          create(:security_orchestration_policy_rule_schedule,
            security_orchestration_policy_configuration: container.security_orchestration_policy_configuration)
        end

        it 'unassigns policy project from the project', :aggregate_failures do
          expect(result).to be_success
          exists = Security::OrchestrationPolicyConfiguration.exists?(
            container.security_orchestration_policy_configuration.id)
          expect(exists).to be(false)
        end

        it 'deletes rule schedules related to the project' do
          expect { result }.to change { Security::OrchestrationPolicyRuleSchedule.count }.from(1).to(0)
        end

        describe 'deletion' do
          let(:policy_configuration) { container.security_orchestration_policy_configuration }

          it 'enqueues for deletion' do
            expect(Security::DeleteOrchestrationConfigurationWorker).to receive(:perform_async).with(
              policy_configuration.id, current_user.id, policy_configuration.security_policy_management_project.id)

            result
          end
        end

        it 'logs audit event' do
          old_policy_project = container.security_orchestration_policy_configuration.security_policy_management_project
          audit_context = {
            name: "policy_project_updated",
            author: current_user,
            scope: container,
            target: old_policy_project,
            message: "Unlinked #{old_policy_project.name} as the security policy project"
          }

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

          result
        end
      end

      context 'when policy project is not assigned to a project or namespace' do
        let(:service) { described_class.new(container: container_without_policy_project, current_user: current_user) }

        it 'respond with an error', :aggregate_failures do
          expect(result).not_to be_success
          expect(result.message).to eq("Policy project doesn't exist")
        end
      end

      context 'when policy project is in designated CSP group' do
        include_context 'with csp group configuration'

        let(:service) { described_class.new(container: csp_group, current_user: current_user) }
        let(:policy_configuration) { csp_group.security_orchestration_policy_configuration }

        it 'respond with an error', :aggregate_failures do
          expect(result).not_to be_success
          expect(result.message).to eq('You cannot unassign security policy project for group designated as CSP.')
        end

        context 'when skip_csp is set to false' do
          subject(:result) { service.execute(skip_csp: false) }

          it 'unassigns policy project from the project', :aggregate_failures do
            expect(result).to be_success
            exists = Security::OrchestrationPolicyConfiguration.exists?(policy_configuration.id)
            expect(exists).to be(false)
          end
        end
      end
    end

    context 'for project' do
      let_it_be_with_reload(:container) { create(:project, :with_security_orchestration_policy_configuration) }
      let_it_be_with_reload(:container_without_policy_project) { create(:project) }

      context 'with approval rules' do
        let(:service) { described_class.new(container: container, current_user: current_user) }

        context 'with scan_finding rule' do
          let_it_be(:merge_request) { create(:merge_request, target_project: container, source_project: container) }

          let_it_be(:scan_finding_rule) do
            create(:approval_project_rule,
              :scan_finding,
              project: container,
              security_orchestration_policy_configuration_id: container.security_orchestration_policy_configuration.id
            )
          end

          let_it_be(:scan_finding_mr_rule) do
            create(:report_approver_rule,
              :scan_finding,
              merge_request: merge_request,
              security_orchestration_policy_configuration_id: container.security_orchestration_policy_configuration.id
            )
          end

          it 'deletes scan finding approval rules related to the project' do
            expect { result }.to change { ApprovalProjectRule.count }.from(1).to(0)
          end

          it 'deletes scan finding approval rules related to the merge requests' do
            expect { result }.to change { ApprovalMergeRequestRule.count }.from(1).to(0)
          end
        end

        context 'with other rule' do
          let_it_be(:license_scanning_rule) { create(:approval_project_rule, :license_scanning, project: container) }

          it 'does not delete license scanning rules' do
            expect { result }.not_to change { ApprovalProjectRule.count }
          end
        end
      end

      context 'when project has a security_policy_bot' do
        let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }
        let(:service) { described_class.new(container: container, current_user: current_user) }

        before_all do
          container.add_guest(security_policy_bot)
        end

        it 'unassigns policy project and enqueues the bot removal worker', :aggregate_failures do
          expect(Security::OrchestrationConfigurationRemoveBotWorker).to receive(:perform_async)
                                                                           .with(container.id, current_user.id)
          expect(result).to be_success

          exists = Security::OrchestrationPolicyConfiguration.exists?(
            container.security_orchestration_policy_configuration.id)
          expect(exists).to be(false)
        end

        context 'when keeping the bot' do
          subject(:result) { service.execute(delete_bot: false) }

          it 'does not enqueue the bot removal worker' do
            expect(Security::OrchestrationConfigurationRemoveBotWorker).not_to receive(:perform_async)

            result
          end
        end
      end

      it_behaves_like 'unassigns policy project'
    end

    context 'for namespace' do
      let_it_be_with_reload(:container) { create(:group, :with_security_orchestration_policy_configuration) }

      context 'when projects have a security_policy_bot' do
        let_it_be(:namespace_projects) { create_list(:project, 2, group: container) }
        let(:service) { described_class.new(container: container, current_user: current_user) }

        before do
          namespace_projects.each do |project|
            bot_user = create(:user, :security_policy_bot)
            project.add_guest(bot_user)
          end
        end

        it 'does not unassign the policy project and enqueues OrchestrationConfigurationRemoveBotForNamespaceWorker',
          :aggregate_failures do
          expect(Security::OrchestrationConfigurationRemoveBotForNamespaceWorker).to receive(:perform_async).with(
            container.id, current_user.id)

          expect(result).to be_success

          exists = Security::OrchestrationPolicyConfiguration.exists?(
            container.security_orchestration_policy_configuration.id)
          expect(exists).to be(true)
        end
      end
    end
  end
end
