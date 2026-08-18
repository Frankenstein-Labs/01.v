# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::BillingDuoWorkflowServiceProbe,
  feature_category: :duo_setting do
  subject(:probe) { described_class.new(user) }

  let(:user) { build(:user) }
  let(:host) { 'duo-workflow-svc.runway.gitlab.net:443' }
  let(:secure) { true }
  let(:token) { 'token-abc' }
  let(:duo_workflow_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }

  before do
    allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(duo_workflow_client)
    allow(Gitlab::DuoWorkflow::Client).to receive(:cloud_connected_url).with(user: user).and_return(host)
    allow(Gitlab::DuoWorkflow::Client).to receive(:secure?).and_return(secure)
    allow(CloudConnector::Tokens).to receive(:get).and_return(token)
  end

  describe '#execute' do
    context 'when the cloud service responds successfully' do
      before do
        allow(duo_workflow_client).to receive(:list_tools).and_return(status: :success)
      end

      it 'returns a success result named after the probe', :aggregate_failures do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.name).to eq(:billing_duo_workflow_service_probe)
        expect(result.success?).to be(true)
        expect(result.message).to eq(
          "The cloud GitLab Duo Agent Platform service at #{host} is reachable for usage billing."
        )
      end

      it 'builds the client with the cloud-connected URL, secure flag, and cloud-connector token',
        :aggregate_failures do
        probe.execute

        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to have_received(:new).with(
          duo_workflow_service_url: host,
          current_user: user,
          secure: secure,
          token: token
        )
        expect(Gitlab::DuoWorkflow::Client).to have_received(:cloud_connected_url).with(user: user)
        expect(CloudConnector::Tokens).to have_received(:get).with(
          unit_primitive: :duo_agent_platform,
          resource: user,
          feature_setting: have_attributes(self_hosted?: false)
        )
      end
    end

    context 'when the cloud service is not reachable' do
      before do
        allow(duo_workflow_client).to receive(:list_tools).and_return(status: :error, message: 'Connection failed')
      end

      it 'returns a failure result referencing usage billing', :aggregate_failures do
        result = probe.execute

        expect(result.success?).to be(false)
        expect(result.message).to eq(
          "The cloud GitLab Duo Agent Platform service at #{host} is not reachable. " \
            "Self-hosted GitLab Duo usage billing will fail until connectivity is restored."
        )
      end
    end
  end
end
