# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ArtifactRegistry::LookupRoleAssignmentsService, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: organization) }

  let(:resource_id) { Gitlab::Utils.uuid_v7 }
  let(:objects) { [{ resource_id: resource_id, ancestor_ids: [] }] }
  let(:roles) { [] }
  let(:page_size) { nil }
  let(:page_after) { nil }
  let(:token) { 'ar-token' }

  let(:client) { instance_double(Authn::IamService::LookupRelationshipsClient) }
  let(:lookup_response) do
    ::Gitlab::Iam::Lookup::V1::LookupRelationshipsResponse.new(
      relationships: [
        ::Gitlab::Iam::Relationships::V1::Relationship.new(
          object: ::Gitlab::Iam::Relationships::V1::Object.new(id: resource_id)
        )
      ],
      next_page_token: 'next-page'
    )
  end

  before do
    issuer = instance_double(Authn::TokenExchange::TokenIssuer, token: token)
    allow(Authn::TokenExchange::TokenIssuer).to receive(:new).and_return(issuer)

    allow(Authn::IamService::LookupRelationshipsClient).to receive(:new).and_return(client)
    allow(client).to receive(:lookup).and_return(lookup_response)
  end

  subject(:execute) do
    described_class.new(
      current_user: current_user,
      organization: organization,
      objects: objects,
      roles: roles,
      page_size: page_size,
      page_after: page_after
    ).execute
  end

  context 'when the query is valid' do
    it 'reads through IAM and returns the relationships and next page token', :aggregate_failures do
      result = execute

      expect(result).to be_success
      expect(result.payload[:role_assignments].map { |r| r.object.id }).to eq([resource_id])
      expect(result.payload[:next_page_token]).to eq('next-page')
    end

    it 'passes the scoped objects, filters, pagination, and token to the client', :aggregate_failures do
      expect(client).to receive(:lookup) do |objects:, kinds:, role_ids:, page_size:, page_token:, token:|
        expect(objects).to match_array([{ id: resource_id, ancestor_ids: [] }])
        expect(kinds).to eq([:KIND_ASSIGNMENT])
        expect(role_ids).to eq([])
        expect(page_size).to be_nil
        expect(page_token).to be_nil
        expect(token).to eq('ar-token')

        lookup_response
      end

      expect(execute).to be_success
    end

    # IAM only accepts canonical lowercase ids, so the service normalizes case
    # instead of rejecting an uppercase id.
    context 'with uppercase resource and ancestor ids' do
      let(:ancestor_id) { Gitlab::Utils.uuid_v7 }
      let(:objects) { [{ resource_id: resource_id.upcase, ancestor_ids: [ancestor_id.upcase] }] }

      it 'downcases the ids before passing them to the client' do
        expect(client).to receive(:lookup) do |objects:, **_kwargs|
          expect(objects).to match_array([{ id: resource_id, ancestor_ids: [ancestor_id] }])

          lookup_response
        end

        expect(execute).to be_success
      end
    end

    context 'with ancestor ids on an object' do
      let(:ancestor_id) { Gitlab::Utils.uuid_v7 }
      let(:objects) { [{ resource_id: resource_id, ancestor_ids: [ancestor_id] }] }

      it 'forwards the ancestors to the client' do
        expect(client).to receive(:lookup)
          .with(hash_including(objects: [{ id: resource_id, ancestor_ids: [ancestor_id] }]))
          .and_return(lookup_response)

        expect(execute).to be_success
      end
    end

    context 'with a role filter' do
      let(:roles) { [:artifact_admin] }

      it 'maps role names to role ids for the client' do
        expect(client).to receive(:lookup)
          .with(hash_including(role_ids: [Authz::ArtifactRegistry::Roles.uuid_for(:artifact_admin)]))
          .and_return(lookup_response)

        expect(execute).to be_success
      end
    end

    context 'for any query' do
      it 'always scopes the read to the assignment kind' do
        expect(client).to receive(:lookup)
          .with(hash_including(kinds: [:KIND_ASSIGNMENT]))
          .and_return(lookup_response)

        expect(execute).to be_success
      end
    end

    context 'with an empty object list' do
      let(:objects) { [] }

      it 'reads the whole organization (IAM enforces the owner requirement)' do
        expect(client).to receive(:lookup)
          .with(hash_including(objects: []))
          .and_return(lookup_response)

        expect(execute).to be_success
      end
    end

    describe 'page size clamping' do
      context 'when the requested size exceeds the cap' do
        let(:page_size) { 5000 }

        it 'clamps to MAX_PAGE_SIZE' do
          expect(client).to receive(:lookup)
            .with(hash_including(page_size: described_class::MAX_PAGE_SIZE))
            .and_return(lookup_response)

          expect(execute).to be_success
        end
      end

      context 'when the requested size is within the cap' do
        let(:page_size) { 50 }

        it 'passes it through' do
          expect(client).to receive(:lookup)
            .with(hash_including(page_size: 50))
            .and_return(lookup_response)

          expect(execute).to be_success
        end
      end

      context 'when the requested size is not positive' do
        let(:page_size) { 0 }

        it 'falls back to the server default (nil)' do
          expect(client).to receive(:lookup)
            .with(hash_including(page_size: nil))
            .and_return(lookup_response)

          expect(execute).to be_success
        end
      end
    end

    context 'when paging with a page token' do
      let(:page_after) { 'opaque-cursor' }

      it 'forwards it as the client page token' do
        expect(client).to receive(:lookup)
          .with(hash_including(page_token: 'opaque-cursor'))
          .and_return(lookup_response)

        expect(execute).to be_success
      end
    end
  end

  context 'when the caller or inputs are invalid' do
    shared_examples 'a rejected lookup' do |message_fragment|
      it 'returns an error and never calls the client', :aggregate_failures do
        expect(client).not_to receive(:lookup)

        result = execute
        expect(result).to be_error
        expect(result.message).to include(message_fragment)
      end
    end

    context 'when there is no current user' do
      let(:current_user) { nil }

      it_behaves_like 'a rejected lookup', 'signed in'
    end

    context 'when the organization is not set' do
      let(:organization) { nil }

      it_behaves_like 'a rejected lookup', 'Organization'
    end

    context 'when the organization is not the caller\'s own' do
      let_it_be(:organization) { create(:organization) }

      # Generic not-found, so it does not disclose that another org exists.
      it_behaves_like 'a rejected lookup', 'could not be found'
    end

    context 'when an object resource id is not a UUID' do
      let(:objects) { [{ resource_id: 'not-a-uuid', ancestor_ids: [] }] }

      it_behaves_like 'a rejected lookup', 'UUIDv7'
    end

    # IAM only accepts UUIDv7 ids, so any other version is rejected here with a
    # precise message rather than failing at IAM with a generic invalid-request
    # error.
    context 'when an object resource id is a UUIDv4' do
      let(:objects) { [{ resource_id: 'c7a3b3f4-9d3a-4e46-9c3e-3a1f0b2d4e5f', ancestor_ids: [] }] }

      it_behaves_like 'a rejected lookup', 'UUIDv7'
    end

    context 'when an ancestor id is not a UUID' do
      let(:objects) { [{ resource_id: resource_id, ancestor_ids: ['not-a-uuid'] }] }

      it_behaves_like 'a rejected lookup', 'UUIDv7'
    end

    context 'when one role filter is unknown' do
      let(:roles) { [:not_a_role] }

      it_behaves_like 'a rejected lookup', 'Unknown Artifact Registry role'
    end

    context 'when several role filters are unknown' do
      let(:roles) { [:not_a_role, :also_bad] }

      it 'reports every unknown role in one error', :aggregate_failures do
        expect(client).not_to receive(:lookup)

        result = execute
        expect(result).to be_error
        expect(result.message).to include('not_a_role', 'also_bad')
      end
    end
  end

  context 'when IAM returns an error' do
    # The client reports a transport reason; the service turns it into the
    # user-facing Artifact Registry message. Lambdas defer s_ to call time so
    # each helper receives a string literal.
    {
      not_found: -> { s_('ArtifactRegistry|The requested resources could not be found.') },
      permission_denied: -> { s_('ArtifactRegistry|You are not authorized to read these role assignments.') },
      unauthenticated: -> { s_('ArtifactRegistry|Could not authenticate with the Artifact Registry service.') },
      invalid_request: -> { s_('ArtifactRegistry|The role assignment lookup request was invalid.') },
      unavailable: -> { s_('ArtifactRegistry|The Artifact Registry service is unavailable.') },
      timeout: -> { s_('ArtifactRegistry|The Artifact Registry service did not respond in time.') },
      unknown: -> { s_('ArtifactRegistry|The role assignment lookup could not be completed.') }
    }.each do |reason, expected_message|
      context "with the #{reason} reason" do
        before do
          allow(client).to receive(:lookup).and_raise(
            Authn::IamService::LookupRelationshipsClient::RequestError.new('diagnostic', reason: reason)
          )
        end

        it 'returns a service error with the mapped message', :aggregate_failures do
          result = execute

          expect(result).to be_error
          expect(result.message).to eq(expected_message.call)
        end
      end
    end
  end
end
