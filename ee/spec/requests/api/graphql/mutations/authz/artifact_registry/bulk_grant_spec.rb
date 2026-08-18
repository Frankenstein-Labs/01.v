# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Bulk granting Artifact Registry roles', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: current_organization) }
  let_it_be(:assignee) { create(:user, organization: current_organization) }
  let_it_be(:assignee_b) { create(:user, organization: current_organization) }

  let(:resource_id) { Gitlab::Utils.uuid_v7 }
  let(:assignments) do
    [{ 'assigneeId' => assignee.to_global_id.to_s, 'resourceId' => resource_id, 'role' => 'ARTIFACT_VIEWER' }]
  end

  let(:mutation) { graphql_mutation(:artifact_registry_role_bulk_grant, { 'assignments' => assignments }) }

  def mutation_response
    graphql_mutation_response(:artifact_registry_role_bulk_grant)
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

    it 'writes every assignment to IAM in one call and returns no errors', :aggregate_failures do
      grants = [
        { 'assigneeId' => assignee.to_global_id.to_s, 'resourceId' => resource_id, 'role' => 'ARTIFACT_VIEWER' },
        { 'assigneeId' => assignee_b.to_global_id.to_s, 'resourceId' => resource_id, 'role' => 'ARTIFACT_ADMIN' }
      ]
      captured_request = nil

      expect_next_instance_of(::Gitlab::Iam::Update::V1::UpdateService::Stub) do |stub|
        expect(stub).to receive(:write_relationships) do |request, metadata:|
          captured_request = request
          expect(metadata['authorization']).to eq('Bearer ar-token')

          ::Gitlab::Iam::Update::V1::WriteRelationshipsResponse.new
        end
      end

      post_graphql_mutation(graphql_mutation(:artifact_registry_role_bulk_grant, { 'assignments' => grants }),
        current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['grantedRoleCount']).to eq(2)

      expect(captured_request.relationships.size).to eq(2)
      expect(captured_request.relationships.map { |r| r.subject.identity.local_id })
        .to match_array([assignee.id.to_s, assignee_b.id.to_s])
      expect(captured_request.relationships.map { |r| r.subject.identity.origin_id })
        .to all(eq(current_organization.uuid))
      expect(captured_request.relationships.map(&:kind)).to all(eq(:KIND_ASSIGNMENT))
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

    context 'when an assignment is invalid' do
      it 'reports a nonexistent user as not found in the payload errors' do
        grants = [{
          'assigneeId' => "gid://gitlab/User/#{non_existing_record_id}",
          'resourceId' => resource_id,
          'role' => 'ARTIFACT_VIEWER'
        }]

        post_graphql_mutation(graphql_mutation(:artifact_registry_role_bulk_grant, { 'assignments' => grants }),
          current_user: current_user)

        expect(mutation_response['errors']).to include(a_string_matching(/could not be found/))
      end

      it 'surfaces a validation error in the payload errors' do
        grants = [{
          'assigneeId' => assignee.to_global_id.to_s,
          'resourceId' => 'not-a-uuid',
          'role' => 'ARTIFACT_VIEWER'
        }]

        post_graphql_mutation(graphql_mutation(:artifact_registry_role_bulk_grant, { 'assignments' => grants }),
          current_user: current_user)

        expect(mutation_response['errors']).to include(a_string_matching(/valid UUID/))
      end
    end

    it 'resolves the assignees without an N+1 query' do
      # The service is mocked here to isolate the mutation's assignee batch-load
      # from the IAM write and token exchange.
      allow_next_instances_of(::Authz::ArtifactRegistry::GrantRoleAssignmentsService, nil) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      grant_for = ->(user) do
        { 'assigneeId' => user.to_global_id.to_s, 'resourceId' => resource_id, 'role' => 'ARTIFACT_VIEWER' }
      end
      run = ->(grants) do
        post_graphql_mutation(graphql_mutation(:artifact_registry_role_bulk_grant, { 'assignments' => grants }),
          current_user: current_user)
      end

      run.call([grant_for.call(assignee)]) # warm up
      control = ActiveRecord::QueryRecorder.new { run.call([grant_for.call(assignee)]) }

      expect { run.call([grant_for.call(assignee), grant_for.call(assignee_b)]) }
        .not_to exceed_query_limit(control)
    end
  end

  context 'when the user is not authenticated' do
    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::GrantRoleAssignmentsService).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: nil)

      expect(graphql_errors).to be_present
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(artifact_registry_role_assignment: false)
    end

    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::GrantRoleAssignmentsService).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to be_present
    end
  end
end
