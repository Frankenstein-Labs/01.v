# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestions::SelfHostedBillingTracker, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }
  let(:feature_setting) { instance_double(Ai::FeatureSetting, self_hosted?: true, feature: 'code_suggestions') }
  let(:grpc_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }

  subject(:tracker) do
    described_class.new(current_user: current_user, feature_setting: feature_setting)
  end

  before do
    allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(grpc_client)
    allow(grpc_client).to receive(:track_self_hosted_client_event)
      .and_return(ServiceResponse.success(message: "Billing event tracked"))
  end

  describe '#track' do
    context 'when self-hosted DAP billing is enabled' do
      before do
        allow(Ai::SelfHostedDapBilling).to receive(:should_bill?).with(feature_setting).and_return(true)
      end

      it 'returns a success response' do
        expect(tracker.track).to be_success
      end

      it 'calls the gRPC client with correct arguments' do
        expect(grpc_client).to receive(:track_self_hosted_client_event).with(
          request_id: anything,
          feature_qualified_name: described_class::FEATURE_QUALIFIED_NAME,
          feature_ai_catalog_item: false
        )

        tracker.track
      end

      it 'builds the gRPC client with the cloud connector token and cloud URL' do
        allow(CloudConnector::Tokens).to receive(:cloud_connector_token).and_return('cloud-token')

        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
          duo_workflow_service_url: Gitlab::DuoWorkflow::Client.cloud_connected_url(user: current_user),
          current_user: current_user,
          secure: Gitlab::DuoWorkflow::Client.secure?,
          token: 'cloud-token'
        )

        tracker.track
      end

      context 'when the gRPC call fails' do
        before do
          allow(grpc_client).to receive(:track_self_hosted_client_event)
            .and_return(ServiceResponse.error(message: "connection refused"))
        end

        it 'returns an error response' do
          expect(tracker.track).to be_error
        end

        it 'surfaces the error message' do
          expect(tracker.track.message).to eq("connection refused")
        end
      end

      context 'when an unexpected exception is raised' do
        before do
          allow(grpc_client).to receive(:track_self_hosted_client_event)
            .and_raise(RuntimeError, "unexpected")
        end

        it 'tracks the exception and returns an error response' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(RuntimeError),
            hash_including(feature: feature_setting.feature)
          )

          expect(tracker.track).to be_error
        end
      end
    end

    context 'when self-hosted DAP billing is disabled' do
      before do
        allow(Ai::SelfHostedDapBilling).to receive(:should_bill?).with(feature_setting).and_return(false)
      end

      it 'returns a success response without calling the gRPC client' do
        expect(grpc_client).not_to receive(:track_self_hosted_client_event)

        expect(tracker.track).to be_success
      end
    end
  end
end
