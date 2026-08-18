# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UpdateProjectComplianceViolation', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let(:error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let(:compliance_violation) { create(:project_compliance_violation, project: project, namespace: group) }

  let(:mutation) do
    graphql_mutation(
      :update_project_compliance_violation,
      {
        id: compliance_violation.to_global_id.to_s,
        status: new_status
      }
    )
  end

  let(:mutation_response) { graphql_mutation_response(:update_project_compliance_violation) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: user) }

  before do
    stub_licensed_features(group_level_compliance_violations_report: true)
  end

  before_all do
    group.add_owner(user)
  end

  shared_examples 'skips audit event and system note creation' do
    it 'does not create any audit event' do
      expect { mutate }.not_to change {
        AuditEventReader.where("details LIKE '%update_project_compliance_violation%'").count
      }
    end

    it 'does not create a system note' do
      expect { mutate }.not_to change { Note.where(noteable_id: compliance_violation.id).count }
    end
  end

  context 'when user has permission to read compliance violations report' do
    context 'with valid parameters' do
      let(:new_status) { 'IN_REVIEW' }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        :update_compliance_violations_report do
        let(:boundary_object) { project }
        let(:mutation) do
          graphql_mutation(:update_project_compliance_violation,
            { id: compliance_violation.to_global_id.to_s, status: new_status }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'updates the compliance violation status' do
        mutate

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['complianceViolation']['id']).to eq(compliance_violation.to_global_id.to_s)
        expect(mutation_response['errors']).to be_empty

        expect(compliance_violation.reload.status).to eq('in_review')
      end

      it 'returns the updated compliance violation' do
        mutate

        expect(mutation_response['complianceViolation']).to include(
          'id' => compliance_violation.to_global_id.to_s,
          'status' => new_status
        )
      end

      it 'audits the change' do
        expect { mutate }.to change {
          AuditEventReader.where("details LIKE '%update_project_compliance_violation%'").count
        }.by(1)
      end

      it 'creates a system note' do
        expect { mutate }.to change { Note.where(noteable_id: compliance_violation.id).count }.by(1)
      end

      context 'when status is same as previous one' do
        let(:new_status) { compliance_violation.status.upcase }

        it 'does return any error' do
          mutate

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
        end

        it_behaves_like 'skips audit event and system note creation'
      end
    end

    context 'with different status values' do
      %w[DETECTED IN_REVIEW RESOLVED DISMISSED].each do |status|
        context "when updating to #{status}" do
          let(:new_status) { status }

          it "successfully updates status to #{status}" do
            mutate

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty
            expect(compliance_violation.reload.status).to eq(status.downcase)
          end
        end
      end
    end

    context 'with invalid parameters' do
      context 'when compliance violation does not exist' do
        let(:mutation) do
          graphql_mutation(
            :update_project_compliance_violation,
            {
              id: "gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/#{non_existing_record_id}",
              status: 'IN_REVIEW'
            }
          )
        end

        it 'returns an error' do
          mutate

          expect(graphql_errors).to include(a_hash_including('message' => error_message))
        end

        it_behaves_like 'skips audit event and system note creation'
      end

      context 'when status is invalid' do
        let(:new_status) { 'INVALID_STATUS' }

        it 'returns a validation error' do
          mutate

          expect(graphql_errors).to include(
            a_hash_including('message' => a_string_matching(/was provided invalid value for status/i))
          )
        end

        it_behaves_like 'skips audit event and system note creation'
      end

      context 'when compliance violation belongs to different project' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:other_project) { create(:project, group: other_group) }
        let_it_be(:other_violation) do
          create(:project_compliance_violation, project: other_project, namespace: other_group)
        end

        let(:mutation) do
          graphql_mutation(
            :update_project_compliance_violation,
            {
              id: other_violation.to_global_id.to_s,
              status: 'IN_REVIEW'
            }
          )
        end

        it 'returns an authorization error' do
          mutate

          expect(graphql_errors).to include(a_hash_including('message' => error_message))
        end

        it_behaves_like 'skips audit event and system note creation'
      end
    end
  end

  context 'when user does not have permission' do
    let(:new_status) { 'IN_REVIEW' }

    before_all do
      group.add_maintainer(user)
    end

    it 'returns an authorization error' do
      mutate

      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end

    it_behaves_like 'skips audit event and system note creation'
  end

  context 'when feature is not licensed' do
    let(:new_status) { 'IN_REVIEW' }

    before do
      stub_licensed_features(group_level_compliance_violations_report: false)
    end

    it 'returns an error' do
      mutate

      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end

    it_behaves_like 'skips audit event and system note creation'
  end
end
