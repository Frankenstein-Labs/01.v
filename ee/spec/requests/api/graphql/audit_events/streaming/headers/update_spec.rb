# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update an external audit event destination header', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:destination) { create(:external_audit_event_destination) }
  let_it_be_with_reload(:header) do
    create(:audit_events_streaming_header, key: 'key-1', external_audit_event_destination: destination)
  end

  let_it_be(:owner) { create(:user) }

  let(:current_user) { owner }
  let(:group) { destination.group }
  let(:mutation) { graphql_mutation(:audit_events_streaming_headers_update, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_streaming_headers_update) }

  let(:input) do
    {
      headerId: header.to_gid,
      key: 'new-key',
      value: 'new-value'
    }
  end

  let(:invalid_input) do
    {
      headerId: header.to_gid,
      key: '',
      value: 'bar'
    }
  end

  shared_examples 'a mutation that does not update a header' do
    it 'does not update a header key' do
      expect { post_graphql_mutation(mutation, current_user: owner) }.not_to change { header.key }
    end

    it 'does not update a header value' do
      expect { post_graphql_mutation(mutation, current_user: owner) }.not_to change { header.value }
    end

    it 'does not create any audit event', :aggregate_failures do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      expect { post_graphql_mutation(mutation, current_user: owner) }.not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    subject { post_graphql_mutation(mutation, current_user: owner) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
      end

      it 'updates the header with the correct attributes', :aggregate_failures do
        expect { subject }
          .to change { header.reload.key }.from('key-1').to('new-key')
          .and change { header.reload.value }.from('bar').to('new-value')
          .and not_change { header.reload.active }
      end

      context 'when active attribute is also updated' do
        let(:input) { super().merge(active: false) }

        it 'updates the header with the correct attributes', :aggregate_failures do
          expect { subject }.to change { header.reload.key }.from('key-1').to('new-key')
                                                            .and change { header.reload.value }
                                                                   .from('bar').to('new-value')
                                                            .and change { header.reload.active }.from(true).to(false)
        end
      end

      context 'when only active attribute is updated' do
        let(:input) do
          {
            headerId: header.to_gid,
            active: false
          }
        end

        it 'updates the header active value' do
          expect { subject }
            .to change { header.reload.active }.from(true).to(false)
            .and not_change { header.reload.key }
            .and not_change { header.reload.value }
        end
      end

      context 'when the header attributes are invalid' do
        let(:mutation) { graphql_mutation(:audit_events_streaming_headers_update, invalid_input) }

        it 'returns correct errors' do
          post_graphql_mutation(mutation, current_user: owner)

          expect(mutation_response['errors']).to contain_exactly("Key can't be blank")
        end

        it 'returns the unmutated attribute values', :aggregate_failures do
          post_graphql_mutation(mutation, current_user: owner)

          expect(mutation_response.dig('header', 'key')).to eq('key-1')
          expect(mutation_response.dig('header', 'value')).to eq('bar')
        end

        it_behaves_like 'a mutation that does not update a header'
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation that does not update a header'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation that does not update a header'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation that does not update a header'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not update a header'
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
