# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::AccessCatalogStorageService, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:service_catalog) do
      {
        "backend_services" => [
          {
            "name" => "ai_gateway",
            "project_url" => "https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist",
            "group" => "group::ai framework",
            "jwt_aud" => "gitlab-ai-gateway"
          },
          {
            "name" => "ai_gateway_agent",
            "project_url" => "unknown",
            "group" => "group::ai framework",
            "jwt_aud" => "gitlab-ai-gateway-agent"
          },
          {
            "name" => "duo_workflow_service",
            "project_url" => "https://gitlab.com/gitlab-org/duo-workflow/duo-workflow-service",
            "group" => "group:ai model validation",
            "jwt_aud" => "gitlab-duo-workflow-service"
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

    shared_examples 'returns an error service response and logs the error' do |error_message|
      it 'returns an error service response' do
        result = service
        expect(result.status).to eq(:error)
        expect(result.message).to eq(error_message)
      end

      it 'logs the error' do
        expect(Gitlab::AppLogger)
          .to receive(:error)
          .with("Cloud Connector Access catalog update failed: #{error_message}")

        service
      end
    end

    shared_examples 'does not create a new record' do
      it 'does not create a new record' do
        expect { service }.not_to change { CloudConnector::Access.count }
      end
    end

    shared_examples 'does not update the existing record' do
      it 'does not update the existing record' do
        expect { service }.not_to change { CloudConnector::Access.last.catalog }
      end
    end

    context 'when no records exist' do
      before do
        CloudConnector::Access.delete_all
      end

      context 'when catalog is provided' do
        subject(:service) { described_class.new(catalog: service_catalog).execute }

        context 'when the valid catalog JSON is provided', :freeze_time do
          it 'creates a new record' do
            expect { service }.to change { CloudConnector::Access.count }.to(1)

            record = CloudConnector::Access.last
            expect(record.catalog).to eq(service_catalog)
            expect(record.updated_at).to eq(Time.current)
          end

          it { is_expected.to be_success }
        end

        context 'when the invalid catalog JSON is provided' do
          subject(:service) { described_class.new(catalog: "invalid").execute }

          include_examples 'does not create a new record'
          include_examples 'returns an error service response and logs the error',
            'Catalog must be a valid json schema'
        end

        context 'when nil provided as catalog' do
          subject(:service) { described_class.new(catalog: nil).execute }

          include_examples 'does not create a new record'
          include_examples 'returns an error service response and logs the error',
            'Catalog can\'t be blank, Catalog must be a valid json schema'
        end
      end
    end

    context 'when the record exists' do
      let_it_be(:cloud_connector_access) do
        create(:cloud_connector_access, catalog: service_catalog)
      end

      let(:new_catalog) do
        {
          "license_types" => [
            { "name" => "premium" },
            { "name" => "ultimate" },
            { "name" => "new" }
          ]
        }
      end

      context 'when catalog is provided' do
        subject(:service) { described_class.new(catalog: new_catalog).execute }

        context 'when the valid catalog JSON is provided', :freeze_time do
          it 'updates the existing record' do
            expect { service }.not_to change { CloudConnector::Access.count }

            record = CloudConnector::Access.last
            expect(record.catalog).to eq(new_catalog)
            expect(record.updated_at).to eq(Time.current)
          end

          it { is_expected.to be_success }
        end

        context 'when the invalid catalog JSON is provided' do
          subject(:service) { described_class.new(catalog: "invalid_json").execute }

          include_examples 'does not update the existing record'
          include_examples 'does not create a new record'
          include_examples 'returns an error service response and logs the error',
            'Catalog must be a valid json schema'
        end

        context 'when nil provided as catalog' do
          subject(:service) { described_class.new(catalog: nil).execute }

          include_examples 'does not update the existing record'
          include_examples 'does not create a new record'
        end
      end
    end
  end
end
