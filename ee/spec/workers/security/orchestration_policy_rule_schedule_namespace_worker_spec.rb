# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationPolicyRuleScheduleNamespaceWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project_1) { create(:project, namespace: namespace) }
    let_it_be(:project_2) { create(:project, namespace: namespace) }
    let_it_be_with_reload(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: namespace) }
    let_it_be_with_reload(:schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: security_orchestration_policy_configuration) }

    let(:schedule_id) { schedule.id }
    let(:worker) { described_class.new }

    before do
      allow(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async)
    end

    context 'when schedule exists' do
      context 'when schedule is created for security orchestration policy configuration in namespace' do
        context 'when next_run_at is in future' do
          before do
            schedule.update_column(:next_run_at, 1.minute.from_now)
          end

          it 'does not execute the rule schedule service' do
            expect(Security::SecurityOrchestrationPolicies::RuleScheduleService).not_to receive(:new)

            worker.perform(schedule_id)
          end
        end

        context 'when next_run_at is in the past' do
          before do
            schedule.update_column(:next_run_at, 1.minute.ago)
          end

          it 'creates async new policy bot user only when it is missing for the project' do
            expect(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).with(project_1.id, nil)
            expect(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).with(project_2.id, nil)
            expect { worker.perform(schedule_id) }.not_to change { User.count }
          end

          it 'does not invoke the rule schedule worker when there is no security policy bot' do
            expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

            worker.perform(schedule_id)
          end

          it 'updates next run at value' do
            worker.perform(schedule_id)

            expect(schedule.reload.next_run_at).to be_future
          end

          it 'does not trigger N+1 queries', :use_sql_query_cache do
            control = ActiveRecord::QueryRecorder.new { worker.perform(schedule_id) }

            create(:project, namespace: namespace)
            create(:project, namespace: namespace)
            schedule.update_column(:next_run_at, 1.minute.ago)

            expect { worker.perform(schedule_id) }.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency.or_fewer
          end

          context 'when there is a security_policy_bot in the project' do
            let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

            before_all do
              project_1.add_guest(security_policy_bot)
            end

            it 'creates async new policy bot user only when it is missing for the project' do
              expect(Security::OrchestrationConfigurationCreateBotWorker).not_to receive(:perform_async).with(project_1.id, nil)
              expect(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).with(project_2.id, nil)
              expect { worker.perform(schedule_id) }.not_to change { User.count }
            end

            it 'invokes the rule schedule worker as the bot user only when it is created for the project' do
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).to receive(:perform_async).with(project_1.id, security_policy_bot.id, schedule.id)
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async).with(project_2.id, anything, schedule.id)

              worker.perform(schedule_id)
            end

            context 'with a CSP group' do
              include_context 'with csp group configuration'

              let_it_be(:other_project) { create(:project) }
              let_it_be(:other_project_2) { create(:project) }
              let_it_be(:other_security_policy_bot) { create(:user, :security_policy_bot) }
              let_it_be(:pending_deletion_security_policy_bot) { create(:user, :security_policy_bot) }
              let_it_be(:project_pending_deletion) { create(:project, namespace: namespace, marked_for_deletion_at: Time.zone.now) }

              before_all do
                other_project.add_guest(other_security_policy_bot)
                project_pending_deletion.add_guest(pending_deletion_security_policy_bot)
                schedule.update!(security_orchestration_policy_configuration: csp_security_orchestration_policy_configuration)
              end

              it 'triggers for all instance projects with policy bot users except those pending deletion' do
                expect(Security::ScanExecutionPolicies::RuleScheduleWorker).to receive(:perform_async).with(project_1.id, security_policy_bot.id, schedule.id)
                expect(Security::ScanExecutionPolicies::RuleScheduleWorker).to receive(:perform_async).with(other_project.id, other_security_policy_bot.id, schedule.id)
                expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async).with(project_2.id, anything, schedule.id)
                expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async).with(other_project_2.id, anything, schedule.id)
                expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async).with(project_pending_deletion.id, anything, schedule.id)

                worker.perform(schedule_id)
              end
            end
          end

          context 'with namespace including project marked for deletion' do
            let_it_be(:security_policy_bot_2) { create(:user, :security_policy_bot) }
            let_it_be(:project_pending_deletion) { create(:project, namespace: namespace, marked_for_deletion_at: Time.zone.now) }

            before_all do
              project_pending_deletion.add_guest(security_policy_bot_2)
            end

            it 'does not call RuleScheduleWorker for the project' do
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async).with(project_pending_deletion.id, schedule.owner.id, schedule.id)

              worker.perform(schedule_id)
            end
          end
        end
      end

      context 'when schedule is created for security orchestration policy configuration in project' do
        before do
          security_orchestration_policy_configuration.update!(project: project_1, namespace: nil)
        end

        it 'does not execute the rule schedule worker' do
          expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

          worker.perform(schedule_id)
        end
      end

      context 'when the cadence is not valid' do
        before do
          schedule.update_column(:cron, '*/5 * * * *')
          schedule.update_column(:next_run_at, 1.minute.ago)
        end

        it 'does not execute the rule schedule worker' do
          expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

          worker.perform(schedule_id)
        end

        it 'logs the error' do
          expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
            event: 'scheduled_scan_execution_policy_validation',
            message: 'Invalid cadence',
            namespace_id: namespace.id,
            cadence: schedule.cron).and_call_original

          worker.perform(schedule_id)
        end
      end
    end

    context 'when schedule does not exist' do
      let(:schedule_id) { non_existing_record_id }

      it 'does not execute the rule schedule worker' do
        expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

        worker.perform(schedule_id)
      end
    end
  end
end
