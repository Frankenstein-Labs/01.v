# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Granting an Artifact Registry role', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: current_organization) }
  let_it_be(:assignee) { create(:user, organization: current_organization) }

  let(:resource_id) { '019ed9d4-0000-7000-8000-000000000000' }
  let(:role) { 'ARTIFACT_VIEWER' }
  let(:input) do
    {
      'assigneeId' => assignee.to_global_id.to_s,
      'resourceId' => resource_id,
      'role' => role
    }
  end

  let(:mutation) { graphql_mutation(:artifact_registry_role_grant, input) }

  def mutation_response
    graphql_mutation_response(:artifact_registry_role_grant)
  end

  context 'when the feature flag is enabled' do
    before do
      # The token exchange has its own specs; stub the minted token so this spec
      # stays focused on the GraphQL-to-IAM write path.
      issuer = instance_double(Authn::TokenExchange::TokenIssuer, token: 'ar-token')
      allow(Authn::TokenExchange::TokenIssuer).to receive(:new).and_return(issuer)

      # Stub IAM data access service config so the ServiceTokenInterceptor can be
      # constructed without reading from disk (secret file is not present in CI).
      allow(Authn::IamDataAccessService).to receive_messages(
        grpc_address: 'localhost:5005',
        secret: 'test-service-token'
      )
    end

    it 'writes the assignment tuple to IAM and returns no errors', :aggregate_failures do
      captured_request = nil

      expect_next_instance_of(::Gitlab::Iam::Update::V1::UpdateService::Stub) do |stub|
        expect(stub).to receive(:write_relationships) do |request, metadata:|
          captured_request = request
          expect(metadata['authorization']).to eq('Bearer ar-token')

          ::Gitlab::Iam::Update::V1::WriteRelationshipsResponse.new
        end
      end

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(captured_request.relationships.size).to eq(1)

      tuple = captured_request.relationships.first
      expect(tuple.subject.identity.origin_id).to eq(current_organization.uuid)
      expect(tuple.subject.identity.local_id).to eq(assignee.id.to_s)
      expect(tuple.object.id).to eq(resource_id)
      expect(tuple.kind).to eq(:KIND_ASSIGNMENT)
    end

    context 'when IAM rejects the write' do
      it 'surfaces the error in the mutation response' do
        allow_next_instance_of(::Gitlab::Iam::Update::V1::UpdateService::Stub) do |stub|
          allow(stub).to receive(:write_relationships)
            .and_raise(GRPC::InvalidArgument.new('bad request'))
        end

        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to be_present
      end
    end
  end

  context 'when the user is not authenticated' do
    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::GrantRoleAssignmentsService).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: nil)

      expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(artifact_registry_role_assignment: false)
    end

    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::GrantRoleAssignmentsService).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
    end
  end
end
