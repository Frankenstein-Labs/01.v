# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update Google Cloud logging configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:config) { create(:google_cloud_logging_configuration) }
  let_it_be_with_reload(:destination) { config }

  let_it_be(:group) { config.group }
  let_it_be(:owner) { create(:user) }
  let_it_be(:updated_google_project_id_name) { 'updated-project' }
  let_it_be(:updated_client_email) { 'updated-email@example.com' }
  let_it_be(:updated_private_key) { OpenSSL::PKey::RSA.new(4096).to_pem }
  let_it_be(:updated_log_id_name) { 'updated_log_id_name' }
  let_it_be(:updated_destination_name) { 'updated_destination_name' }
  let_it_be(:config_gid) { global_id_of(config) }

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:google_cloud_logging_configuration_update, input) }
  let(:mutation_response) { graphql_mutation_response(:google_cloud_logging_configuration_update) }
  let(:mutation_name) { :google_cloud_logging_configuration_update }
  let(:mutation_field) { 'googleCloudLoggingConfiguration' }
  let(:model) { config }
  let(:event_name) { Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Update::UPDATE_EVENT_NAME }

  let(:input) do
    {
      id: config_gid,
      googleProjectIdName: updated_google_project_id_name,
      clientEmail: updated_client_email,
      privateKey: updated_private_key,
      logIdName: updated_log_id_name,
      name: updated_destination_name,
      active: true
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: owner) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
        allow(Gitlab::Audit::Auditor).to receive(:audit)
      end

      it_behaves_like 'entity owner updating google cloud logging configuration' do
        let(:audit_scope) { group }
        let(:audit_event_name) { Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Update::UPDATE_EVENT_NAME }
      end

      context 'when there is error while updating' do
        before do
          allow_next_instance_of(Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Update) do |mutation|
            allow(mutation).to receive(:authorized_find!).with(config_gid).and_return(config)
          end

          allow(config).to receive(:update).and_return(false)

          errors = ActiveModel::Errors.new(config).tap { |e| e.add(:base, 'error message') }
          allow(config).to receive(:errors).and_return(errors)
        end

        it 'does not update the configuration and returns the error' do
          mutate

          expect(mutation_response).to include(
            'googleCloudLoggingConfiguration' => nil,
            'errors' => ['error message']
          )
        end
      end

      context 'when updating a legacy destination' do
        let(:stream_destination) do
          create(:audit_events_group_external_streaming_destination, :gcp, group: group,
            legacy_destination_ref: config.id)
        end

        it_behaves_like 'audits legacy active status changes'

        it_behaves_like 'updates a streaming destination',
          :config,
          proc {
            {
              legacy: {
                "log_id_name" => updated_log_id_name,
                "client_email" => updated_client_email,
                "google_project_id_name" => updated_google_project_id_name,
                "name" => updated_destination_name
              },
              streaming: {
                "logIdName" => updated_log_id_name,
                "clientEmail" => updated_client_email,
                "googleProjectIdName" => updated_google_project_id_name,
                "name" => updated_destination_name
              }
            }
          }
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the google cloud logging configuration'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the google cloud logging configuration'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the google cloud logging configuration'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not update the google cloud logging configuration'
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
