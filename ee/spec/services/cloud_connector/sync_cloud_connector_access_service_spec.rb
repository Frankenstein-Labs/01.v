# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SyncCloudConnectorAccessService, :freeze_time, feature_category: :plan_provisioning do
  describe '#execute' do
    shared_examples 'returns error with proper message' do |message|
      it 'returns error' do
        expect(sync_cloud_connector_access.error?).to eq(true)
      end

      it 'returns error message' do
        expect(sync_cloud_connector_access[:message]).to eq(message)
      end
    end

    shared_examples 'no Cloud Connector Access sync' do |message|
      it 'does not execute SubscriptionPortal GraphQl cloudConnectorAccess query' do
        expect(Gitlab::SubscriptionPortal::Client).not_to receive(:get_cloud_connector_access_data)

        sync_cloud_connector_access
      end

      include_examples 'returns error with proper message', message
    end

    shared_examples 'Cloud Connector Access sync' do
      before do
        allow(Gitlab::SubscriptionPortal::Client).to(
          receive(:get_cloud_connector_access_data)
            .with(expected_license.data)
            .and_return(response)
        )
      end

      context 'when graphql query response is successful' do
        let(:response) do
          { success: true, token: token, expires_at: expires_at, catalog: catalog }
        end

        let(:token_storage_service_response) { ServiceResponse.success }
        let(:access_data_storage_service_response) { ServiceResponse.success }
        let(:token) { 'token' }
        let(:expires_at) { Time.current.iso8601.to_s }

        let(:catalog) do
          {
            "backend_services" => [
              {
                "name" => "ai_gateway_agent",
                "project_url" => "unknown",
                "group" => "group::ai framework",
                "jwt_aud" => "gitlab-ai-gateway-agent"
              }
            ],
            "unit_primitives" => [
              {
                "name" => "agent_quick_actions",
                "description" => "Quick actions for agent.",
                "group" => "group::duo_chat",
                "feature_category" => "duo_chat",
                "backend_services" => ["ai_gateway_agent"],
                "license_types" => ["ultimate"]
              }
            ],
            "add_ons" => [
              { "name" => "duo_enterprise" },
              { "name" => "duo_pro" }
            ],
            "license_types" => [
              { "name" => "premium" },
              { "name" => "ultimate" }
            ]
          }
        end

        before do
          allow_next_instance_of(CloudConnector::ServiceAccessTokensStorageService, token, expires_at) do |service|
            allow(service).to receive(:execute).and_return(token_storage_service_response)
          end

          allow_next_instance_of(CloudConnector::AccessCatalogStorageService,
            { catalog: catalog }) do |service|
            allow(service).to receive(:execute).and_return(access_data_storage_service_response)
          end
        end

        it 'executed SubscriptionPortal GraphQL cloudConnectorAccess query' do
          expect(Gitlab::SubscriptionPortal::Client).to receive(:get_cloud_connector_access_data)

          sync_cloud_connector_access
        end

        context 'when token and access data is successfully stored' do
          it 'returns successful response' do
            expect(sync_cloud_connector_access.success?).to eq(true)
          end
        end

        context 'when token is not successfully stored' do
          let(:token_storage_service_response) { ServiceResponse.error(message: 'Token Error') }

          include_examples 'returns error with proper message', 'Token Error'
        end

        context 'when access data is not successfully stored' do
          let(:access_data_storage_service_response) { ServiceResponse.error(message: 'Access Data Error') }

          include_examples 'returns error with proper message', 'Access Data Error'
        end

        context 'when both token and access data are not successfully stored' do
          let(:token_storage_service_response) { ServiceResponse.error(message: 'Token Error') }
          let(:access_data_storage_service_response) { ServiceResponse.error(message: 'Access Data Error') }

          include_examples 'returns error with proper message', 'Token Error, Access Data Error'
        end
      end

      context 'when graphql query response is not successful' do
        let(:response) { { success: false, errors: ["GraphQL Error"] } }

        include_examples 'returns error with proper message', 'GraphQL Error'
      end
    end

    subject(:sync_cloud_connector_access) { described_class.new(expected_license).execute }

    context 'with license checks' do
      let(:expected_license) { license }

      context 'when license is valid cloud license' do
        let!(:license) { create_current_license(cloud_licensing_enabled: true, starts_at: '2020-02-12'.to_date) }

        include_examples 'Cloud Connector Access sync'
      end

      context 'when more than one license exists' do
        let!(:expected_license) do
          create(:license, data: create(:gitlab_license, cloud_licensing_enabled: true).export)
        end

        let!(:license) do
          # This test ensures that we do not rely on License.current, which maintains an in-memory
          # cache that can drift across different instances of this service object executing in
          # different processes, but instead always load the given license from the database.
          create(:license, data: create(:gitlab_license, cloud_licensing_enabled: true).export)
        end

        include_examples 'Cloud Connector Access sync'
      end

      context 'when license is missing' do
        let!(:license) { nil }

        before do
          License.current.destroy!
        end

        include_examples 'no Cloud Connector Access sync', 'License not found'
      end

      context 'when using a trial license' do
        let!(:license) do
          create_current_license(cloud_licensing_enabled: true, restrictions: { trial: true })
        end

        include_examples 'Cloud Connector Access sync'
      end

      context 'when the license has no expiration date' do
        let!(:license) do
          create_current_license_without_expiration(cloud_licensing_enabled: true, block_changes_at: nil)
        end

        include_examples 'no Cloud Connector Access sync', 'License has no expiration date'
      end

      context 'when using an expired license' do
        let!(:license) do
          create_current_license(cloud_licensing_enabled: true, expires_at: Time.zone.now.utc.to_date - 10.days)
        end

        include_examples 'Cloud Connector Access sync'
      end

      context 'when using an expired license, and grace period has passed' do
        let!(:license) do
          create_current_license(cloud_licensing_enabled: true, expires_at: Time.zone.now.utc.to_date - 15.days)
        end

        include_examples 'no Cloud Connector Access sync', 'License grace period has been expired'
      end

      context 'with a non offline cloud license' do
        let!(:license) do
          create_current_license(cloud_licensing_enabled: true, offline_cloud_licensing_enabled: true)
        end

        include_examples 'no Cloud Connector Access sync', 'License is not an online cloud license'
      end

      context 'with a non cloud license' do
        let!(:license) do
          create_current_license(starts_at: '2020-02-12'.to_date)
        end

        include_examples 'no Cloud Connector Access sync', 'License is not an online cloud license'
      end
    end
  end
end
