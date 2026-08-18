# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete denylist event type filters for a group streaming destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination) }
  let_it_be(:group) { destination.group }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:filter) do
    create(:audit_events_group_event_type_filters,
      external_streaming_destination: destination,
      audit_event_type: 'event_type_filters_created',
      kind: :deny)
  end

  let(:event_type_filters) { ['event_type_filters_created'] }
  let(:input) do
    {
      destination_id: global_id_of(destination).to_s,
      event_type_filters: event_type_filters
    }
  end

  let(:mutation) { graphql_mutation(:audit_events_group_destination_denylist_events_delete, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_group_destination_denylist_events_delete) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      it 'removes the denylist filter' do
        expect { mutate }.to change { destination.event_type_denylist_filters.count }.by(-1)

        expect(mutation_response['errors']).to be_empty
      end

      context 'when the filter does not exist' do
        let(:event_type_filters) { ['unknown_event'] }

        it 'returns an error message' do
          mutate

          expect(mutation_response['errors']).to include(a_string_including('unknown_event'))
        end
      end
    end

    context 'when current user is a group maintainer' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when feature is unlicensed' do
    before_all do
      group.add_owner(current_user)
    end

    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:user) }

    before_all do
      group.add_owner(granular_token_user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
