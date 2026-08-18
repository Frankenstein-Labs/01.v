# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update an external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:destination) do
    create(:external_audit_event_destination, name: "Old Destination", destination_url: "https://example.com/old",
      group: group)
  end

  let_it_be(:destination_url) { 'https://example.com/new' }
  let_it_be(:name) { 'New Destination' }

  let(:current_user) { owner }
  let(:destination_id) { GitlabSchema.id_from_object(destination) }

  let(:input) do
    {
      id: destination_id,
      destinationUrl: destination_url,
      name: name
    }
  end

  let(:mutation_name) { :external_audit_event_destination_update }
  let(:mutation_field) { 'externalAuditEventDestination' }
  let(:model) { destination }
  let(:event_name) { 'update_event_streaming_destination' }
  let(:mutation) { graphql_mutation(mutation_name, input) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  shared_examples 'a mutation that does not update a destination' do
    it 'does not update the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { destination.reload.destination_url }
    end

    it 'does not audit the update' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner but destination belongs to another group' do
      before do
        group.add_owner(owner)
        destination.update!(group: create(:group))
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group owner of a different group' do
      before do
        group_2 = create(:group)
        group_2.add_owner(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
      end

      it 'updates the destination_url' do
        expect do
          post_graphql_mutation(mutation, current_user: owner)
        end.to change { destination.reload.destination_url }.to(destination_url)
      end

      it 'updates the destination name' do
        expect do
          post_graphql_mutation(mutation, current_user: owner)
        end.to change { destination.reload.name }.to(name)
      end

      it_behaves_like 'audits update to external streaming destination' do
        let_it_be(:current_user) { owner }
      end

      it_behaves_like 'audits legacy active status changes'

      context 'when there is no change in values' do
        let(:input) do
          {
            id: destination_id,
            destinationUrl: destination.reload.destination_url
          }
        end

        it_behaves_like 'a mutation that does not update a destination'
      end

      context 'when updating a legacy destination' do
        let(:stream_destination) do
          create(:audit_events_group_external_streaming_destination, :http, group: group,
            legacy_destination_ref: destination.id)
        end

        it_behaves_like 'updates a streaming destination',
          :destination,
          proc {
            {
              legacy: {
                "destination_url" => destination_url,
                "name" => name
              },
              streaming: {
                "url" => destination_url,
                "name" => name
              }
            }
          }
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation that does not update a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { destination.reload.destination_url }
    end
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
