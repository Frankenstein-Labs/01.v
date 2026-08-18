# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete an instance level audit event type filter', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:destination) { create(:audit_events_instance_external_streaming_destination) }

  let(:mutation_name) { :audit_events_instance_destination_events_delete }
  let(:mutation) { graphql_mutation(mutation_name, input) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:input) { { destinationId: destination.to_gid, eventTypeFilters: ['event_type_filters_created'] } }

  before_all do
    create(:audit_events_instance_event_type_filters, external_streaming_destination: destination,
      audit_event_type: 'event_type_filters_created')
    create(:audit_events_instance_event_type_filters, external_streaming_destination: destination,
      audit_event_type: 'event_type_filters_deleted')
  end

  context 'when current user is instance admin' do
    let(:current_user) { create(:admin) }

    subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

    context 'when licensed' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      shared_examples 'deletes event filter' do
        it do
          expect { mutate }.to change { destination.event_type_filters.count }.by(-1)

          expect(mutation_response["errors"]).to be_empty
        end
      end

      context 'when all params are correct' do
        it_behaves_like 'deletes event filter'
      end

      context 'when destination id is not in input params' do
        let(:input) { { eventTypeFilters: ['event_type_filters_created'] } }

        it 'returns error', :aggregate_failures do
          expect { mutate }.not_to change { AuditEvents::Instance::EventTypeFilter.count }

          expect(graphql_errors.to_s).to include("invalid value for destinationId (Expected value to not be null")
        end
      end

      context 'when destination id is not existing' do
        let(:input) do
          {
            destinationId: "gid://gitlab/AuditEvents::Instance::ExternalStreamingDestination/#{non_existing_record_id}",
            eventTypeFilters: ['event_type_filters_created']
          }
        end

        it 'does not delete any event filter' do
          expect { mutate }.not_to change { AuditEvents::Instance::EventTypeFilter.count }
        end

        it_behaves_like 'a mutation on an unauthorized resource'
      end

      context 'when event filters is not in input params' do
        let(:input) { { destinationId: destination.to_gid } }

        it 'returns error', :aggregate_failures do
          expect { mutate }.not_to change { destination.event_type_filters.count }

          expect(graphql_errors.to_s).to include("invalid value for eventTypeFilters (Expected value to not be null")
        end
      end

      context 'when event filters is not an array' do
        let(:input) { { destinationId: destination.to_gid, eventTypeFilters: 'event_type_filters_created' } }

        it_behaves_like 'deletes event filter'
      end

      context 'when the given event filters does not exist for the destination' do
        let(:input) do
          { destinationId: destination.to_gid, eventTypeFilters: ['audit_events_streaming_headers_create'] }
        end

        it 'returns error', :aggregate_failures do
          expect { mutate }.not_to change { destination.event_type_filters.count }

          expect(mutation_response["errors"])
            .to eq(["Couldn't find event type filters where audit event type(s): " \
                    "audit_events_streaming_headers_create"])
        end
      end

      context 'when event type filters in input is empty' do
        let(:input) { { destinationId: destination.to_gid, eventTypeFilters: [] } }

        it 'returns graphql error' do
          expect { mutate }.not_to change { AuditEvents::Instance::EventTypeFilter.count }

          expect(graphql_errors).to include(a_hash_including('message' => 'event type filters must be present'))
        end
      end
    end

    context 'when unlicensed' do
      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when current user is not instance admin' do
    let(:current_user) { create(:user) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
