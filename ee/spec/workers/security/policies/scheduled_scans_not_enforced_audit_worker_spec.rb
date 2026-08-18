# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policies::ScheduledScansNotEnforcedAuditWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:schedule) do
      create(:security_orchestration_policy_rule_schedule,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let(:project_id) { project.id }
    let(:current_user_id) { current_user.id }
    let(:schedule_id) { schedule.id }
    let_it_be(:branch) { 'main' }

    subject(:run_worker) { described_class.new.perform(project_id, current_user_id, schedule_id, branch) }

    shared_examples_for 'does not call ScheduledScansNotEnforcedAuditor' do
      specify do
        expect(Security::SecurityOrchestrationPolicies::ScheduledScansNotEnforcedAuditor).not_to receive(:new)

        run_worker
      end
    end

    context 'when project is not found' do
      let(:project_id) { non_existing_record_id }

      it_behaves_like 'does not call ScheduledScansNotEnforcedAuditor'
    end

    context 'when project exist' do
      let(:project_id) { project.id }

      context 'when security_orchestration_policies feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'does not call ScheduledScansNotEnforcedAuditor'
      end

      context 'when security_orchestration_policies feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when the scheduled is not found' do
          let(:schedule_id) { non_existing_record_id }

          it_behaves_like 'does not call ScheduledScansNotEnforcedAuditor'
        end

        context 'when the current_user is not found' do
          let(:current_user_id) { non_existing_record_id }

          it_behaves_like 'does not call ScheduledScansNotEnforcedAuditor'
        end

        it 'calls ScheduledScansNotEnforcedAuditor' do
          expect_next_instance_of(Security::SecurityOrchestrationPolicies::ScheduledScansNotEnforcedAuditor,
            project: project,
            author: current_user,
            schedule: schedule,
            branch: branch) do |auditor|
            expect(auditor).to receive(:audit)
          end

          run_worker
        end

        it_behaves_like 'an idempotent worker' do
          let(:job_args) { [project_id, current_user_id, schedule_id, branch] }
        end
      end
    end
  end
end
