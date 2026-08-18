# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unlinking a merge request from a vulnerability', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:merge_request_link) do
    create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
  end

  let(:vulnerability_gid) { GitlabSchema.id_from_object(vulnerability).to_s }
  let(:merge_request_gid) { GitlabSchema.id_from_object(merge_request).to_s }

  let(:mutation) do
    graphql_mutation(
      :vulnerability_unlink_merge_request,
      vulnerability_id: vulnerability_gid,
      merge_request_id: merge_request_gid
    )
  end

  def mutation_response
    graphql_mutation_response(:vulnerability_unlink_merge_request)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  context 'when user is not authenticated' do
    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: nil)

      expect(graphql_errors).to include(
        a_hash_including(
          'message' => 'The resource that you are attempting to access does not exist or you don\'t have ' \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when user does not have permission' do
    before_all do
      project.add_reporter(user)
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(graphql_errors).to include(
        a_hash_including(
          'message' => 'The resource that you are attempting to access does not exist or you don\'t have ' \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when user has permission' do
    before_all do
      project.add_developer(user)
    end

    context 'when unlinking succeeds' do
      it 'unlinks the merge request from the vulnerability' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .to change { vulnerability.merge_request_links.count }.by(-1)

        expect(graphql_errors).to be_blank
        expect(mutation_response).not_to be_nil
        expect(mutation_response['vulnerability']['id']).to eq(vulnerability_gid)
        expect(mutation_response['errors']).to be_empty
      end

      it 'returns the vulnerability' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_errors).to be_blank
        vulnerability_response = mutation_response['vulnerability']
        expect(vulnerability_response).not_to be_nil
        expect(vulnerability_response['id']).to eq(vulnerability_gid)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        :delete_vulnerability_merge_request_link do
        let(:boundary_object) { project }
        let(:authz_mutation) do
          graphql_mutation(
            :vulnerability_unlink_merge_request,
            { vulnerability_id: vulnerability_gid, merge_request_id: merge_request_gid },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'when merge request is not linked' do
      let_it_be(:unlinked_merge_request) do
        create(:merge_request, source_project: project, source_branch: 'feature-branch')
      end

      let(:unlinked_merge_request_gid) { GitlabSchema.id_from_object(unlinked_merge_request).to_s }

      let(:unlinked_mutation) do
        graphql_mutation(
          :vulnerability_unlink_merge_request,
          vulnerability_id: vulnerability_gid,
          merge_request_id: unlinked_merge_request_gid
        )
      end

      it 'returns an error' do
        post_graphql_mutation(unlinked_mutation, current_user: user)

        expect(mutation_response['vulnerability']['id']).to eq(vulnerability_gid)
        expect(mutation_response['errors']).to include('Merge request is not linked to this vulnerability')
      end
    end

    context 'when merge request does not exist' do
      let(:invalid_merge_request_gid) do
        GitlabSchema.id_from_object(build(:merge_request, id: non_existing_record_id)).to_s
      end

      let(:invalid_mutation) do
        graphql_mutation(
          :vulnerability_unlink_merge_request,
          vulnerability_id: vulnerability_gid,
          merge_request_id: invalid_merge_request_gid
        )
      end

      it 'returns an error' do
        post_graphql_mutation(invalid_mutation, current_user: user)

        expect(mutation_response['vulnerability']['id']).to eq(vulnerability_gid)
        expect(mutation_response['errors']).to include(
          'The merge request does not exist or you do not have permission to view it.'
        )
      end
    end

    context 'when vulnerability does not exist' do
      let(:invalid_vulnerability_gid) do
        GitlabSchema.id_from_object(build(:vulnerability, id: non_existing_record_id)).to_s
      end

      let(:invalid_mutation) do
        graphql_mutation(
          :vulnerability_unlink_merge_request,
          vulnerability_id: invalid_vulnerability_gid,
          merge_request_id: merge_request_gid
        )
      end

      it 'returns an error' do
        post_graphql_mutation(invalid_mutation, current_user: user)

        expect(graphql_errors).to include(
          a_hash_including(
            'message' => 'The resource that you are attempting to access does not exist or you don\'t have ' \
              'permission to perform this action'
          )
        )
      end
    end

    context 'when unlinking fails due to service error' do
      before do
        allow_next_instance_of(VulnerabilityMergeRequestLinks::DestroyService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Service error', payload: { errors: ['Service error'] })
          )
        end
      end

      it 'returns an error' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .not_to change { Vulnerabilities::MergeRequestLink.count }

        expect(mutation_response['vulnerability']['id']).to eq(vulnerability_gid)
        expect(mutation_response['errors']).to include('Service error')
      end
    end
  end
end
