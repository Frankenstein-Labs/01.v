# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetEscalationPolicy, feature_category: :incident_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:escalation_policy) { create(:incident_management_escalation_policy, project: project) }
  let_it_be_with_reload(:issue) { create(:incident, project: project) }
  let_it_be_with_reload(:escalation_status) { create(:incident_management_issuable_escalation_status, issue: issue) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let(:escalation_policy_id) { escalation_policy.to_global_id }
    let(:args) { { escalation_policy_id: escalation_policy_id } }
    let(:mutated_issue) { result[:issue] }

    subject(:result) { mutation.resolve(project_path: issue.project.full_path, iid: issue.iid, **args) }

    before do
      stub_licensed_features(oncall_schedules: true, escalation_policies: true)
    end

    it_behaves_like 'permission level for issue mutation is correctly verified', true

    context 'when the user can update the issue' do
      before_all do
        project.add_reporter(current_user)
      end

      it_behaves_like 'permission level for issue mutation is correctly verified', true

      context 'when the user can update the escalation status' do
        before_all do
          project.add_developer(current_user)
        end

        it 'returns the issue with the escalation policy' do
          expect(mutated_issue).to eq(issue)
          expect(mutated_issue.escalation_status.policy).to eq(escalation_policy)
          expect(result[:errors]).to be_empty
        end

        it 'returns errors when issue update fails' do
          issue.update_column(:author_id, nil)

          expect(result[:errors]).not_to be_empty
        end

        context 'with non-incident issue is provided' do
          let_it_be(:issue) { create(:issue, project: project) }

          it 'raises an error' do
            expect { result }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, 'Feature unavailable for provided issue')
          end
        end

        context 'when passing escalation_policy_id as nil' do
          let(:args) { { escalation_policy_id: nil } }

          before do
            escalation_status.update!(policy: escalation_policy, escalations_started_at: Time.current)
          end

          it 'removes the escalation policy' do
            expect(mutated_issue.escalation_status.policy).to be_nil
          end
        end

        context 'when escalation_policy_id does not exist' do
          let(:escalation_policy_id) do
            ::Types::GlobalIDType[::IncidentManagement::EscalationPolicy]
              .coerce_isolated_input("gid://gitlab/IncidentManagement::EscalationPolicy/#{non_existing_record_id}")
          end

          it 'raises an execution error with the loads-style message' do
            expect { result }.to raise_error(
              GraphQL::ExecutionError,
              "No object found for `escalationPolicyId: #{escalation_policy_id.to_s.inspect}`"
            )
          end
        end

        context 'when user cannot read the escalation policy' do
          let_it_be(:other_project) { create(:project, :private) }
          let_it_be(:escalation_policy) do
            create(:incident_management_escalation_policy, project: other_project)
          end

          it 'raises a resource not available error' do
            expect { result }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end
    end
  end
end
