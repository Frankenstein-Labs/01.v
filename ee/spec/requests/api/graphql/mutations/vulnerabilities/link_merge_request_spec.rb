# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Linking a merge request to a vulnerability', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

  let(:vulnerability_gid) { GitlabSchema.id_from_object(vulnerability).to_s }
  let(:merge_request_gid) { GitlabSchema.id_from_object(merge_request).to_s }

  let(:readiness_score) { 0.8 }

  let(:mutation) do
    graphql_mutation(
      :vulnerability_link_merge_request,
      vulnerability_id: vulnerability_gid,
      merge_request_id: merge_request_gid,
      readiness_score: readiness_score
    )
  end

  def mutation_response
    graphql_mutation_response(:vulnerability_link_merge_request)
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
      project.add_maintainer(user)
    end

    context 'when linking succeeds' do
      it 'links the merge request to the vulnerability' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .to change { vulnerability.merge_request_links.where(readiness_score: 0.8).count }.by(1)

        expect(graphql_errors).to be_blank
        expect(mutation_response).not_to be_nil
        expect(mutation_response['vulnerability']['id']).to eq(vulnerability_gid)
        expect(mutation_response['errors']).to be_empty
      end

      it 'returns the vulnerability with linked merge requests' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_errors).to be_blank
        vulnerability_response = mutation_response['vulnerability']
        expect(vulnerability_response).not_to be_nil
        expect(vulnerability_response['id']).to eq(vulnerability_gid)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        :create_vulnerability_merge_request_link do
        let(:boundary_object) { project }
        let(:authz_mutation) do
          graphql_mutation(
            :vulnerability_link_merge_request,
            { vulnerability_id: vulnerability_gid, merge_request_id: merge_request_gid },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
      end
    end

    describe 'created_by_ai_workflow' do
      # Select only `errors` so the response does not include vulnerability fields
      # (e.g. userPermissions) that an ai_workflows-scoped token cannot resolve.
      let(:errors_only_mutation) do
        graphql_mutation(
          :vulnerability_link_merge_request,
          { vulnerability_id: vulnerability_gid, merge_request_id: merge_request_gid },
          'errors'
        )
      end

      context 'when the request is made with an ai_workflows-scoped token' do
        let_it_be(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

        it 'records the link as created by an AI workflow', :aggregate_failures do
          post_graphql_mutation(errors_only_mutation, token: { oauth_access_token: oauth_token })

          expect(graphql_errors).to be_blank
          expect(vulnerability.merge_request_links.order(:id).last.created_by_ai_workflow).to be(true)
        end
      end

      context 'when the request is made by a session/api user' do
        it 'does not mark the link as created by an AI workflow', :aggregate_failures do
          post_graphql_mutation(errors_only_mutation, current_user: user)

          expect(graphql_errors).to be_blank
          expect(vulnerability.merge_request_links.order(:id).last.created_by_ai_workflow).to be(false)
        end
      end
    end

    context 'when merge request is already linked' do
      before do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['vulnerability']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/already linked/))
      end
    end

    context 'when merge request does not exist' do
      let(:invalid_merge_request_gid) do
        GitlabSchema.id_from_object(build(:merge_request, id: non_existing_record_id)).to_s
      end

      let(:invalid_mutation) do
        graphql_mutation(
          :vulnerability_link_merge_request,
          vulnerability_id: vulnerability_gid,
          merge_request_id: invalid_merge_request_gid
        )
      end

      it 'returns an error' do
        post_graphql_mutation(invalid_mutation, current_user: user)

        expect(mutation_response['vulnerability']).to be_nil
        expect(mutation_response['errors']).to include(
          'The merge request does not exist or you do not have permission to view it.'
        )
      end
    end

    context 'with readiness_score validation' do
      context 'when readiness_score is invalid' do
        let(:readiness_score) { 1.5 }

        it 'returns validation errors' do
          expect { post_graphql_mutation(mutation, current_user: user) }
            .not_to change { Vulnerabilities::MergeRequestLink.count }

          expect(mutation_response['vulnerability']).to be_nil
          expect(mutation_response['errors']).to include('Readiness score is not included in the list')
        end
      end
    end

    context 'when linking fails due to limit exceeded' do
      before do
        stub_const('Vulnerabilities::MergeRequestLink::MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY', 1)
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
      end

      it 'returns an error about exceeding the limit' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .not_to change { Vulnerabilities::MergeRequestLink.count }

        expected_message = format(
          _('Cannot link more than %{limit} merge requests to a vulnerability'),
          limit: Vulnerabilities::MergeRequestLink::MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY
        )

        expect(mutation_response['vulnerability']).to be_nil
        expect(mutation_response['errors']).to include(expected_message)
      end
    end
  end
end
