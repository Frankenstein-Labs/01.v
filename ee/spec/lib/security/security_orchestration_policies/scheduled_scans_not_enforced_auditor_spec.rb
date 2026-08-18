# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ScheduledScansNotEnforcedAuditor, feature_category: :security_policy_management do
  describe '#audit' do
    let_it_be(:project) { create(:project) }
    let_it_be(:author) { create(:user) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:schedule) do
      create(:security_orchestration_policy_rule_schedule,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:branch) { 'main' }

    subject(:audit) { described_class.new(project: project, author: author, schedule: schedule, branch: branch).audit }

    shared_examples 'does not call Gitlab::Audit::Auditor' do
      specify do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit
      end
    end

    shared_examples 'calls Gitlab::Audit::Auditor.audit with the expected context' do
      specify do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            {
              name: 'security_policy_scheduled_scans_not_enforced',
              author: expected_author,
              scope: policy_configuration.security_policy_management_project,
              target: schedule,
              target_details: schedule.id.to_s,
              message: "Schedule: #{schedule.id} created by security policies could not be enforced",
              additional_details: {
                target_branch: branch,
                project_id: project.id,
                project_name: project.name,
                project_full_path: project.full_path,
                skipped_policy: { name: expected_policy_name, policy_type: schedule.policy_type }
              }
            }
          )
        )

        audit
      end
    end

    context 'when the schedule is nil' do
      let(:schedule) { nil }

      it_behaves_like 'does not call Gitlab::Audit::Auditor'
    end

    context 'when the schedule is present' do
      context 'when project is nil' do
        let_it_be(:project) { nil }

        it_behaves_like 'does not call Gitlab::Audit::Auditor'
      end

      context 'when project is present' do
        let(:policy) do
          {
            name: 'Scheduled DAST 1',
            description: 'This policy runs DAST for every 20 mins',
            enabled: true,
            rules: [{ type: 'schedule', branches: %w[production], cadence: '*/20 * * * *' }],
            actions: [
              { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }
            ]
          }
        end

        let(:expected_policy_name) { policy[:name] }
        let(:expected_author) { author }

        before do
          allow(schedule).to receive(:policy).and_return(policy)
        end

        it_behaves_like 'calls Gitlab::Audit::Auditor.audit with the expected context'

        context 'when the schedule author is nil' do
          let_it_be(:author) { nil }
          let(:expected_author) {  a_kind_of(::Gitlab::Audit::DeletedAuthor) }

          it_behaves_like 'calls Gitlab::Audit::Auditor.audit with the expected context'
        end

        context 'when the policy is nil' do
          let_it_be(:policy) { nil }
          let(:expected_policy_name) { nil }

          it_behaves_like 'calls Gitlab::Audit::Auditor.audit with the expected context'
        end
      end
    end
  end
end
