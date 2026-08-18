# frozen_string_literal: true

require 'spec_helper'
require_relative 'probes/test_probe'

RSpec.describe CloudConnector::StatusChecks::StatusService, feature_category: :duo_setting do
  let_it_be(:license) { create(:license) }
  let(:succeeded_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: true) }
  let(:failed_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: false) }
  let(:user) { build(:user) }
  let(:ai_gateway_url) { 'http://localhost:5002' }

  subject(:service) { described_class.new(user: user, probes: probes) }

  describe '#initialize' do
    subject(:service) { described_class.new(user: user) }

    let(:duo_agent_platform_probe) { an_instance_of(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe) }

    let(:foundational_flows_probes) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::AllowFlowExecutionProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::AllowFoundationalFlowsProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::CompatibleRunnerProbe)
      ]
    end

    let(:default_probes_without_dap) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe),
        *foundational_flows_probes
      ]
    end

    let(:default_probes) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe),
        duo_agent_platform_probe,
        *foundational_flows_probes
      ]
    end

    let(:self_hosted_only_probes) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe)
      ]
    end

    let(:self_hosted_probes) { self_hosted_only_probes + foundational_flows_probes + [duo_agent_platform_probe] }

    before do
      allow(::License).to receive(:current).and_return(license)
      allow(license).to receive(:offline_cloud_license?).and_return(false)

      allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
    end

    context 'when no probes are passed' do
      it 'creates default probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(10)
        expect(service_probes).to match(default_probes)
      end
    end

    context 'when self-hosted AI Gateway URL is set up' do
      before do
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
      end

      it 'uses self-hosted probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(7)
        expect(service_probes).to match(self_hosted_probes)
      end

      context 'when both code completions and DAP are vendored' do
        before do
          create(:instance_model_selection_feature_setting, :code_completions)
          create(:instance_model_selection_feature_setting,
            feature: :duo_agent_platform,
            offered_model_ref: 'claude-3-7-sonnet-20250219',
            offered_model_name: 'Claude 3.7 Sonnet 20250219')
        end

        it 'adds default probes to the list of probes' do
          service_probes = service.probes

          expect(service_probes.count).to eq(13)
          expect(service_probes).to match(
            default_probes_without_dap + self_hosted_only_probes + [duo_agent_platform_probe]
          )
        end
      end
    end

    context 'when Amazon Q is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      it 'adds Amazon Q probes to the list of probes' do
        amazon_q_probes = default_probes + [
          an_instance_of(CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe)
        ]

        expect(service.probes).to match(amazon_q_probes)
      end
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
      let(:local_host_probe) { instance_double(CloudConnector::StatusChecks::Probes::HostProbe) }

      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'true')

        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
      end

      it 'uses a different set of probes' do
        expect(CloudConnector::StatusChecks::Probes::HostProbe).to(
          receive(:new).with(ai_gateway_url).and_return(local_host_probe)
        )

        service_probes = service.probes

        expect(service_probes.count).to eq(2)
        expect(service_probes[0]).to be(local_host_probe)
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      end
    end

    context 'when self-hosted Duo usage billing prerequisites are met' do
      let(:billing_probes) do
        [
          an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingCustomersDotProbe),
          an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingCloudAiGatewayProbe),
          an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingDuoWorkflowServiceProbe)
        ]
      end

      before do
        allow(license).to receive(:online_cloud_license?).and_return(true)
        allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('localhost:50052')
      end

      it 'appends the billing prerequisite probes to the default branch' do
        expect(service.probes.last(3)).to match(billing_probes)
      end

      context 'when self-hosted AI Gateway URL is set up' do
        before do
          allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
        end

        it 'appends the billing prerequisite probes to the self-hosted branch' do
          expect(service.probes.last(3)).to match(billing_probes)
        end
      end
    end
  end

  describe '#execute' do
    context 'when all probes succeed' do
      let(:probes) { [succeeded_probe, succeeded_probe] }

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be true
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to be_nil
      end
    end

    context 'when any probe fails' do
      let(:probes) { [succeeded_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(succeeded_probe).to receive(:execute).and_call_original
        expect(failed_probe).to receive(:execute).and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when all probes fail' do
      let(:probes) { [failed_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(failed_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when a probe returns multiple results' do
      let(:probe_with_multiple_results) { succeeded_probe }
      let(:probes) { [failed_probe, probe_with_multiple_results] }

      it 'executes all probes and returns unsuccessful status result' do
        allow(probe_with_multiple_results).to receive(:execute).and_return([
          ::CloudConnector::StatusChecks::Probes::ProbeResult.new('test', true, 'success'),
          ::CloudConnector::StatusChecks::Probes::ProbeResult.new('test', false, 'failure')
        ])

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].map(&:message)).to contain_exactly('NOK', 'success', 'failure')
        expect(result.message).to eq('Some probes failed')
      end
    end
  end
end
