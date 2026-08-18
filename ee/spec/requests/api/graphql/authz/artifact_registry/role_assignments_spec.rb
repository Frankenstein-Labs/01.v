# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Artifact Registry role assignments lookup', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: current_organization) }
  let_it_be(:assignee) { create(:user, organization: current_organization) }

  let(:resource_id) { Gitlab::Utils.uuid_v7 }
  let(:resource_ids) { [resource_id] }

  let(:role_assignment) do
    ::Gitlab::Iam::Relationships::V1::Relationship.new(
      subject: ::Gitlab::Iam::Relationships::V1::Subject.new(
        identity: ::Gitlab::Iam::Relationships::V1::Identity.new(local_id: assignee.id.to_s)
      ),
      object: ::Gitlab::Iam::Relationships::V1::Object.new(id: resource_id),
      kind: :KIND_ASSIGNMENT,
      role: ::Gitlab::Iam::Relationships::V1::Role.new(id: Authz::ArtifactRegistry::Roles.uuid_for(:artifact_admin))
    )
  end

  let(:service_response) do
    ServiceResponse.success(payload: { role_assignments: [role_assignment], next_page_token: 'next' })
  end

  let(:query) do
    graphql_query_for(
      :artifact_registry_role_assignments,
      { resourceIds: resource_ids, first: 10 },
      <<~FIELDS
        nodes { resourceId role assignee { id username } }
        pageInfo { hasNextPage endCursor }
      FIELDS
    )
  end

  def assignments
    graphql_data_at(:artifact_registry_role_assignments, :nodes)
  end

  context 'when the feature flag is enabled and the query is valid' do
    before do
      allow_next_instance_of(::Authz::ArtifactRegistry::LookupRoleAssignmentsService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end
    end

    it 'returns the role assignments as a connection', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(assignments.size).to eq(1)

      node = assignments.first
      expect(node['resourceId']).to eq(resource_id)
      expect(node['role']).to eq('ARTIFACT_ADMIN')
      expect(node['assignee']['id']).to eq(assignee.to_global_id.to_s)
      expect(graphql_data_at(:artifact_registry_role_assignments, :pageInfo, :endCursor)).to eq('next')
    end

    it 'reads through the service scoped to the given resources and page size', :aggregate_failures do
      received = nil
      allow(::Authz::ArtifactRegistry::LookupRoleAssignmentsService).to receive(:new) do |**kwargs|
        received = kwargs
        instance_double(::Authz::ArtifactRegistry::LookupRoleAssignmentsService, execute: service_response)
      end

      post_graphql(query, current_user: current_user)

      expect(received[:objects]).to eq([{ resource_id: resource_id, ancestor_ids: [] }])
      expect(received[:page_size]).to eq(10)
      expect(received[:organization]).to eq(current_organization)
    end

    it 'forwards the role filter and pagination cursor to the service', :aggregate_failures do
      received = nil
      allow(::Authz::ArtifactRegistry::LookupRoleAssignmentsService).to receive(:new) do |**kwargs|
        received = kwargs
        instance_double(::Authz::ArtifactRegistry::LookupRoleAssignmentsService, execute: service_response)
      end

      filtered_query = graphql_query_for(
        :artifact_registry_role_assignments,
        { resourceIds: resource_ids, roles: [:ARTIFACT_VIEWER], first: 10, after: 'opaque-cursor' },
        'nodes { resourceId }'
      )

      post_graphql(filtered_query, current_user: current_user)

      expect(received[:roles]).to eq([:artifact_viewer])
      expect(received[:page_after]).to eq('opaque-cursor')
    end

    # The connection renders at most max_page_size nodes while the end cursor
    # comes from IAM, so the fetch must be clamped to the same bound or the
    # rows between them would be silently skipped.
    it 'never fetches more from IAM than the connection can render', :aggregate_failures do
      received = nil
      allow(::Authz::ArtifactRegistry::LookupRoleAssignmentsService).to receive(:new) do |**kwargs|
        received = kwargs
        instance_double(::Authz::ArtifactRegistry::LookupRoleAssignmentsService, execute: service_response)
      end

      max = ::Resolvers::Authz::ArtifactRegistry::RoleAssignmentsResolver::MAX_PAGE_SIZE

      oversized_query = graphql_query_for(
        :artifact_registry_role_assignments,
        { resourceIds: resource_ids, first: max + 50 },
        'nodes { resourceId }'
      )
      post_graphql(oversized_query, current_user: current_user)
      expect(received[:page_size]).to eq(max)

      unbounded_query = graphql_query_for(
        :artifact_registry_role_assignments,
        { resourceIds: resource_ids },
        'nodes { resourceId }'
      )
      post_graphql(unbounded_query, current_user: current_user)
      expect(received[:page_size]).to eq(max)
    end

    context 'when the service returns an error' do
      let(:service_response) { ServiceResponse.error(message: 'The requested resources could not be found.') }

      it 'surfaces a top-level error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_present
      end
    end
  end

  context 'when the user is not authenticated' do
    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::LookupRoleAssignmentsService).not_to receive(:new)

      post_graphql(query, current_user: nil)

      expect(graphql_errors).to be_present
    end
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(artifact_registry_role_assignment: false)
    end

    it 'returns a top-level error and does not call the service' do
      expect(::Authz::ArtifactRegistry::LookupRoleAssignmentsService).not_to receive(:new)

      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_present
    end
  end
end
