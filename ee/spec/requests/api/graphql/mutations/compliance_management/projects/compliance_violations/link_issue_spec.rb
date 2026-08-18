# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LinkProjectComplianceViolationIssue', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:violation) { create(:project_compliance_violation, project: project, namespace: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:violation_gid) { violation.to_global_id.to_s }
  let(:issue_iid) { issue.iid.to_s }
  let(:project_path) { project.full_path }

  let(:mutation) do
    graphql_mutation(
      :link_project_compliance_violation_issue,
      violation_id: violation_gid,
      project_path: project_path,
      issue_iid: issue_iid
    )
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: user) }

  def mutation_response
    graphql_mutation_response(:link_project_compliance_violation_issue)
  end

  shared_examples 'unauthorized or unauthorized user' do
    it 'returns an authorization error' do
      mutate

      expect(graphql_errors).to include(a_hash_including('message' => <<~MESSAGE.strip))
        The resource that you are attempting to access does not exist or you don't have permission to perform this action
      MESSAGE
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(group_level_compliance_violations_report: true)
    end

    context 'when user is authenticated and authorized' do
      before_all do
        group.add_owner(user)
      end

      context 'when params are correct' do
        it_behaves_like 'authorizing granular token permissions for GraphQL',
          :update_compliance_violations_report do
          let(:boundary_object) { project }
          let(:mutation) do
            graphql_mutation(:link_project_compliance_violation_issue,
              { violation_id: violation_gid, project_path: project_path, issue_iid: issue_iid }, 'errors')
          end

          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end

        it 'links the issue to the violation' do
          expect { mutate }.to change { violation.reload.issues.count }.by(1)

          expect(mutation_response).to include(
            'violation' => a_hash_including('id' => violation_gid),
            'errors' => be_empty
          )
        end

        context 'when issue is already linked to violation' do
          before do
            create(:project_compliance_violation_issue, project_compliance_violation: violation, issue: issue,
              project: project)
          end

          it 'returns an error' do
            mutate

            expect(mutation_response).to include(
              'violation' => a_hash_including('id' => violation_gid),
              'errors' => include("Issue ID #{issue.id} is already linked to violation ID #{violation.id}")
            )
          end

          it 'does not create duplicate links' do
            expect { mutate }.not_to change { violation.reload.issues.count }
          end
        end
      end

      context 'when violation does not exist' do
        let(:violation_gid) do
          "gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/#{non_existing_record_id}"
        end

        it_behaves_like 'unauthorized or unauthorized user'
      end

      context 'when issue does not exist' do
        let(:issue_iid) { non_existing_record_id.to_s }

        it_behaves_like 'unauthorized or unauthorized user'
      end
    end

    context 'when user is not authorized to read violations' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'unauthorized or unauthorized user'
    end

    context 'when user is not authorized to read issue' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_issue) { create(:issue, project: other_project) }
      let(:issue_gid) { other_issue.iid.to_s }
      let(:project_path) { other_project.full_path }

      it_behaves_like 'unauthorized or unauthorized user'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(group_level_compliance_violations_report: false)
    end

    before_all do
      group.add_owner(user)
    end

    it_behaves_like 'unauthorized or unauthorized user'
  end
end
