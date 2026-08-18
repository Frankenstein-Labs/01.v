# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ArtifactRegistry::GrantRoleAssignmentsService, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: organization) }
  let_it_be(:assignee_a) { create(:user, organization: organization) }
  let_it_be(:assignee_b) { create(:user, organization: organization) }

  let(:resource_id) { Gitlab::Utils.uuid_v7 }
  let(:token) { 'ar-token' }
  let(:client) { instance_double(Authn::IamService::UpdateRelationshipsClient) }
  let(:assignments) do
    [
      { assignee: assignee_a, resource_id: resource_id, role: :artifact_viewer },
      { assignee: assignee_b, resource_id: resource_id, role: :artifact_admin }
    ]
  end

  subject(:execute) do
    described_class.new(current_user: current_user, organization: organization, assignments: assignments).execute
  end

  before do
    issuer = instance_double(Authn::TokenExchange::TokenIssuer, token: token)
    allow(Authn::TokenExchange::TokenIssuer).to receive(:new).and_return(issuer)

    allow(Authn::IamService::UpdateRelationshipsClient).to receive(:new).and_return(client)
    allow(client).to receive(:grant_roles).and_return(::Gitlab::Iam::Update::V1::WriteRelationshipsResponse.new)
  end

  context 'when all assignments are valid' do
    it 'writes every assignment in a single call and returns success', :aggregate_failures do
      expect(client).to receive(:grant_roles) do |inputs, organization_uuid:, token:|
        expect(token).to eq('ar-token')
        expect(organization_uuid).to eq(organization.uuid)
        expect(inputs.map { |i| i[:assignee_id] }).to match_array([assignee_a.id, assignee_b.id])
        expect(inputs.map { |i| i[:role_id] })
          .to match_array([Authz::ArtifactRegistry::Roles.uuid_for(:artifact_viewer),
            Authz::ArtifactRegistry::Roles.uuid_for(:artifact_admin)])
        expect(inputs).to all(include(resource_id: resource_id))

        ::Gitlab::Iam::Update::V1::WriteRelationshipsResponse.new
      end

      result = execute
      expect(result).to be_success
      expect(result.payload[:granted_role_count]).to eq(2)
    end
  end

  context 'when there is no current user' do
    let(:current_user) { nil }

    it 'returns an error and does not call IAM', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('signed in')
    end
  end

  context 'when the organization could not be determined' do
    let(:organization) { nil }

    it 'returns an error and does not call IAM', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('Organization')
    end
  end

  context 'when the organization is not the caller\'s own' do
    let_it_be(:organization) { create(:organization) }

    it 'returns an error and does not call IAM', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('another organization')
    end
  end

  context 'when no assignments are given' do
    let(:assignments) { [] }

    it 'returns an error and does not call IAM', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('At least one')
    end
  end

  context 'when one assignee belongs to a different organization' do
    let_it_be(:other_org_user) { create(:user, organization: create(:organization)) }

    let(:assignments) do
      [
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_viewer },
        { assignee: other_org_user, resource_id: resource_id, role: :artifact_viewer }
      ]
    end

    it 'writes nothing and returns the generic not-found error', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('could not be found')
    end
  end

  context 'when one assignee is nil (user not found)' do
    let(:assignments) do
      [{ assignee: nil, resource_id: resource_id, role: :artifact_viewer }]
    end

    it 'writes nothing and returns the generic not-found error', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('could not be found')
    end
  end

  context 'when one resource_id is not a valid UUID' do
    let(:assignments) do
      [{ assignee: assignee_a, resource_id: 'not-a-uuid', role: :artifact_viewer }]
    end

    it 'writes nothing and returns the bare message without a position prefix', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('UUIDv7')
      expect(result.message).not_to include('Assignment ')
    end
  end

  # IAM only accepts UUIDv7 ids, so any other version is rejected here with a
  # precise message rather than failing at IAM with a generic invalid-request
  # error.
  context 'when one resource_id is a UUIDv4' do
    let(:assignments) do
      [{ assignee: assignee_a, resource_id: 'c7a3b3f4-9d3a-4e46-9c3e-3a1f0b2d4e5f', role: :artifact_viewer }]
    end

    it 'writes nothing and returns an error', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('UUIDv7')
    end
  end

  # IAM only accepts canonical lowercase ids, so the service normalizes case
  # instead of rejecting an uppercase id.
  context 'when one resource_id is an uppercase UUIDv7' do
    let(:assignments) do
      [{ assignee: assignee_a, resource_id: resource_id.upcase, role: :artifact_viewer }]
    end

    it 'downcases the id before writing it', :aggregate_failures do
      expect(client).to receive(:grant_roles) do |inputs, **_kwargs|
        expect(inputs).to all(include(resource_id: resource_id))

        ::Gitlab::Iam::Update::V1::WriteRelationshipsResponse.new
      end

      expect(execute).to be_success
    end
  end

  context 'when one role is unknown' do
    let(:assignments) do
      [{ assignee: assignee_a, resource_id: resource_id, role: :not_a_role }]
    end

    it 'writes nothing and returns an error', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('Unknown Artifact Registry role')
    end
  end

  context 'when several assignments are invalid for different reasons' do
    let(:assignments) do
      [
        { assignee: assignee_a, resource_id: 'not-a-uuid', role: :artifact_viewer },
        { assignee: assignee_b, resource_id: resource_id, role: :not_a_role }
      ]
    end

    it 'reports every validation error, identified by position', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('Assignment 1 on resource not-a-uuid', 'UUIDv7')
      expect(result.message).to include("Assignment 2 on resource #{resource_id}", 'Unknown Artifact Registry role')
    end
  end

  context 'when an assignee is listed twice for the same resource' do
    let(:assignments) do
      [
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_viewer },
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_admin }
      ]
    end

    it 'writes nothing and returns an error naming the assignee, resource, and roles', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include('more than once')
      expect(result.message).to include(assignee_a.to_global_id.to_s)
      expect(result.message).to include(resource_id)
      expect(result.message).to include('ARTIFACT_VIEWER', 'ARTIFACT_ADMIN')
    end
  end

  context 'when several assignees are each duplicated' do
    let(:assignments) do
      [
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_viewer },
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_admin },
        { assignee: assignee_b, resource_id: resource_id, role: :artifact_viewer },
        { assignee: assignee_b, resource_id: resource_id, role: :artifact_contributor }
      ]
    end

    it 'lists every duplicated assignee in the error', :aggregate_failures do
      expect(client).not_to receive(:grant_roles)

      result = execute
      expect(result).to be_error
      expect(result.message).to include(assignee_a.to_global_id.to_s)
      expect(result.message).to include(assignee_b.to_global_id.to_s)
    end
  end

  context 'when an assignee is granted on two different resources' do
    let(:other_resource_id) { Gitlab::Utils.uuid_v7 }
    let(:assignments) do
      [
        { assignee: assignee_a, resource_id: resource_id, role: :artifact_viewer },
        { assignee: assignee_a, resource_id: other_resource_id, role: :artifact_admin }
      ]
    end

    it 'is allowed and writes both' do
      expect(client).to receive(:grant_roles)

      expect(execute).to be_success
    end
  end

  context 'when IAM returns an error' do
    {
      permission_denied: s_('ArtifactRegistry|You are not authorized to grant this role on this resource.'),
      unauthenticated: s_('ArtifactRegistry|Could not authenticate with the Artifact Registry service.'),
      invalid_request: s_('ArtifactRegistry|The role assignment request was invalid.'),
      unavailable: s_('ArtifactRegistry|The Artifact Registry service is unavailable.'),
      timeout: s_('ArtifactRegistry|The Artifact Registry service did not respond in time.'),
      unknown: s_('ArtifactRegistry|The role assignment could not be completed.')
    }.each do |reason, expected_message|
      context "with the #{reason} reason" do
        before do
          allow(client).to receive(:grant_roles).and_raise(
            Authn::IamService::UpdateRelationshipsClient::RequestError.new('diagnostic', reason: reason)
          )
        end

        it 'returns a service error with the mapped message', :aggregate_failures do
          result = execute

          expect(result).to be_error
          expect(result.message).to eq(expected_message)
        end
      end
    end
  end
end
