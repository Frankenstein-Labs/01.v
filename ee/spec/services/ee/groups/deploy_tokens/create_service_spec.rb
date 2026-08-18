# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DeployTokens::CreateService, feature_category: :continuous_delivery do
  let_it_be(:entity) { create(:group) }
  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: entity) }
  let_it_be(:user) { create(:user) }

  let(:deploy_token_params) { default_attributes }

  def default_attributes(overrides = {})
    {
      name: 'Deploy Token',
      read_repository: true
    }.merge(overrides)
  end

  describe '#execute' do
    subject { described_class.new(entity, user, deploy_token_params).execute }

    context 'when the deploy token is valid' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      it 'creates an audit event' do
        expect { subject }.to change { AuditEventReader.count }.by(1)

        expected_message = <<~MESSAGE.squish
          Created group deploy token with name: #{subject[:deploy_token].name}
          with token_id: #{subject[:deploy_token].id} with scopes: #{subject[:deploy_token].scopes}.
        MESSAGE

        expect(AuditEventReader.last.details[:custom_message]).to eq(expected_message)
      end

      it_behaves_like 'sends correct event type in audit event stream' do
        let_it_be(:event_type) { "group_deploy_token_created" }
      end

      context 'when group is a sub-group' do
        let_it_be(:parent_group) { create :group }
        let_it_be(:group) { create :group, parent: parent_group, owners: user }

        subject { described_class.new(group, user, deploy_token_params).execute }

        include_examples 'sends streaming audit event'
      end
    end

    context 'when the deploy token is invalid' do
      let(:deploy_token_params) { default_attributes(read_repository: false, read_registry: false, write_registry: false) }

      before do
        stub_licensed_features(external_audit_events: true)
      end

      it 'creates an audit event' do
        expect { subject }.to change { AuditEventReader.count }.by(1)

        expected_message = "Attempted to create group deploy token but failed with message: Scopes can't be blank"

        expect(AuditEventReader.last.details[:custom_message]).to eq(expected_message)
      end

      it_behaves_like 'sends correct event type in audit event stream' do
        let_it_be(:event_type) { "group_deploy_token_creation_failed" }
      end
    end
  end
end
