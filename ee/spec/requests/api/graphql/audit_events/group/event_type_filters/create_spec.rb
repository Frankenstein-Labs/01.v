# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an audit event type filter', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination) }
  let_it_be(:event_type_filter) do
    create(:audit_events_group_event_type_filters, external_streaming_destination: destination,
      audit_event_type: 'event_type_filters_created')
  end

  let_it_be(:user) { create(:user) }

  let_it_be(:current_user) { user }
  let(:group) { destination.group }
  let_it_be(:mutation_name) { :audit_events_group_destination_events_add }
  let(:mutation) { graphql_mutation(mutation_name, input) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let_it_be(:input) { { destinationId: destination.to_gid, eventTypeFilters: ['event_type_filters_deleted'] } }

  subject { post_graphql_mutation(mutation, current_user: user) }

  before do
    stub_licensed_features(external_audit_events: true)
  end

  context 'when current user is a group maintainer' do
    before do
      group.add_maintainer(user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is a group owner' do
    before do
      group.add_owner(user)
    end

    include_examples 'create event type filters for external audit event destinations' do
      let_it_be(:non_existing_destination_id) do
        "gid://gitlab/AuditEvents::Group::ExternalStreamingDestination/#{non_existing_record_id}"
      end
    end
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:user) }

    before do
      stub_licensed_features(external_audit_events: true)
      group.add_owner(granular_token_user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
