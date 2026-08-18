# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update an instance external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:old_destination_url) { "https://example.com/old" }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:destination) do
    create(:instance_external_audit_event_destination,
      name: "Old Destination",
      destination_url: old_destination_url)
  end

  let_it_be(:destination_url) { 'https://example.com/test' }
  let_it_be(:name) { "My Destination" }

  let(:input) do
    {
      id: GitlabSchema.id_from_object(destination).to_s,
      destinationUrl: destination_url,
      name: name
    }
  end

  let(:mutation_name) { :instance_external_audit_event_destination_update }
  let(:mutation_field) { 'instanceExternalAuditEventDestination' }
  let(:model) { destination }
  let(:mutation) { graphql_mutation(:instance_external_audit_event_destination_update, input) }
  let(:event_name) { 'update_instance_event_streaming_destination' }

  let(:mutation_response) { graphql_mutation_response(:instance_external_audit_event_destination_update) }

  let_it_be(:current_user) { admin }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'a mutation that does not update destination' do
    it 'does not update the destination' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { destination.reload.destination_url }

      expect(graphql_data['instanceExternalAuditEventDestination']).to be_nil
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: ['You do not have access to this mutation.']

    it 'does not audit the update' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      it 'updates the destination with correct response' do
        expect { post_graphql_mutation(mutation, current_user: admin) }
          .to change { destination.reload.destination_url }.to("https://example.com/test")

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['instanceExternalAuditEventDestination']['destinationUrl']).to eq(destination_url)
        expect(mutation_response['instanceExternalAuditEventDestination']['id']).not_to be_empty
        expect(mutation_response['instanceExternalAuditEventDestination']['name']).to eq(name)
        expect(mutation_response['instanceExternalAuditEventDestination']['verificationToken']).not_to be_empty
      end

      it_behaves_like 'audits update to external streaming destination'
      it_behaves_like 'audits legacy active status changes'

      context 'when destination is same as previous one' do
        let(:input) { super().merge(destinationUrl: old_destination_url) }

        it 'updates the destination with correct response' do
          expect { post_graphql_mutation(mutation, current_user: admin) }
            .not_to change { destination.reload.destination_url }

          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['instanceExternalAuditEventDestination']['destinationUrl'])
            .to eq(old_destination_url)
          expect(mutation_response['instanceExternalAuditEventDestination']['id']).not_to be_empty
          expect(mutation_response['instanceExternalAuditEventDestination']['verificationToken']).not_to be_empty
        end
      end

      context 'when the destination id is invalid' do
        let_it_be(:invalid_destination_input) do
          {
            id: "gid://gitlab/AuditEvents::InstanceExternalAuditEventDestination/-1",
            destinationUrl: destination_url
          }
        end

        let(:mutation) do
          graphql_mutation(:instance_external_audit_event_destination_update, invalid_destination_input)
        end

        it 'does not update destination' do
          expect { post_graphql_mutation(mutation, current_user: admin) }
            .not_to change { destination.reload.destination_url }
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end

      context 'when updating a legacy destination' do
        let(:stream_destination) do
          create(:audit_events_instance_external_streaming_destination, :http,
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

    context 'when current user is not instance admin' do
      before do
        sign_in user
      end

      it_behaves_like 'a mutation that does not update destination' do
        let_it_be(:current_user) { user }
      end
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation that does not update destination' do
      let_it_be(:current_user) { admin }
    end
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
