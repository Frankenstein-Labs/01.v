# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationPolicyRuleScheduleWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be_with_reload(:schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: security_orchestration_policy_configuration) }
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    subject(:worker) { described_class.new }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      allow(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async)
    end

    context 'when schedule exists' do
      before do
        schedule.update_column(:next_run_at, 1.minute.ago)
      end

      context 'when schedule is created for security orchestration policy configuration in project' do
        context 'when policy bot user is missing for the project' do
          context 'when feature is not licensed' do
            before do
              stub_licensed_features(security_orchestration_policies: false)
            end

            it 'does not create new policy bot user' do
              expect(Security::OrchestrationConfigurationCreateBotWorker).not_to receive(:perform_async)

              worker.perform
            end
          end

          context 'when feature is licensed' do
            it 'creates async new policy bot user' do
              expect(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).with(project.id, nil)
              expect { worker.perform }.not_to change { User.count }
            end

            it 'does not invoke the rule schedule worker' do
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

              worker.perform
            end

            it 'does not update next run at value' do
              expect { worker.perform }.not_to change { schedule.reload.next_run_at }
            end
          end
        end

        context 'when policy bot user exists for the project' do
          before do
            create(:project_member, user: security_policy_bot, project: project)
          end

          context 'when feature is licensed' do
            it 'invokes the rule schedule worker' do
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).to receive(:perform_async)

              worker.perform
            end
          end

          context 'when feature is not licensed' do
            before do
              stub_licensed_features(security_orchestration_policies: false)
            end

            it 'does not invoke the rule schedule worker' do
              expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

              worker.perform
            end

            it 'does not update next run at value' do
              expect { worker.perform }.not_to change { schedule.reload.next_run_at }
            end
          end
        end

        context 'when project is marked for deletion' do
          before do
            security_orchestration_policy_configuration.project.update!(marked_for_deletion_at: Time.zone.now)
          end

          it 'does not invoke the rule schedule worker' do
            expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

            worker.perform
          end
        end
      end

      context 'when policy has a security_policy_bot user' do
        let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
        let_it_be_with_reload(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration) }
        let_it_be_with_reload(:schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: security_orchestration_policy_configuration) }

        before do
          security_orchestration_policy_configuration.project.add_guest(security_policy_bot)
        end

        it 'updates next run at value' do
          worker.perform

          expect(schedule.reload.next_run_at).to be_future
        end

        it 'invokes the rule schedule worker with the bot user' do
          expect(Security::ScanExecutionPolicies::RuleScheduleWorker).to receive(:perform_async).with(schedule.security_orchestration_policy_configuration.project.id, security_policy_bot.id, schedule.id)

          worker.perform
        end

        context 'when the cadence is not valid' do
          before do
            schedule.update_column(:cron, '*/5 * * * *')
            schedule.update_column(:next_run_at, 1.minute.ago)
          end

          it 'does not invoke rule schedule worker' do
            expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

            worker.perform
          end

          it 'logs the error' do
            expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
              event: 'scheduled_scan_execution_policy_validation',
              message: 'Invalid cadence',
              project_id: security_orchestration_policy_configuration.project.id,
              cadence: schedule.cron).and_call_original

            worker.perform
          end
        end
      end

      context 'when schedule is created for security orchestration policy configuration in namespace' do
        let_it_be(:namespace) { create(:group) }

        before do
          security_orchestration_policy_configuration.update!(namespace: namespace, project: nil)
        end

        it 'schedules the OrchestrationPolicyRuleScheduleNamespaceWorker for namespace' do
          expect(Security::OrchestrationPolicyRuleScheduleNamespaceWorker).to receive(:perform_async).with(schedule.id)

          worker.perform
        end
      end
    end

    context 'when schedule does not exist' do
      before do
        schedule.update_column(:next_run_at, 1.minute.from_now)
      end

      it 'does not invoke rule schedule worker' do
        expect(Security::ScanExecutionPolicies::RuleScheduleWorker).not_to receive(:perform_async)

        worker.perform
      end
    end

    context 'when multiple schedules exists' do
      before do
        schedule.update_column(:next_run_at, 1.minute.ago)
      end

      def record_preloaded_queries
        recorder = ActiveRecord::QueryRecorder.new { worker.perform }
        recorder.data.values.flat_map { |v| v[:occurrences] }.select do |query|
          ['FROM "projects"', 'FROM "users"', 'FROM "security_orchestration_policy_configurations"'].any? do |s|
            query.include?(s)
          end
        end
      end

      it 'preloads configuration, project and owner to avoid N+1 queries' do
        expected_count = record_preloaded_queries.count

        travel_to(30.minutes.ago) { create_list(:security_orchestration_policy_rule_schedule, 5) }
        actual_count = record_preloaded_queries.count

        expect(actual_count).to eq(expected_count)
      end
    end
  end
end
