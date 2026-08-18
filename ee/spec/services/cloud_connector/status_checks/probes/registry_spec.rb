# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::Registry, feature_category: :duo_setting do
  let_it_be(:license) { create(:license) }
  let(:user) { build(:user) }
  let(:offline_license) { false }
  let(:self_hosted_dws_url) { nil }
  let(:dap_probe_class) { CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe }

  let(:foundational_flows_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::AllowFlowExecutionProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::AllowFoundationalFlowsProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::FoundationalFlows::CompatibleRunnerProbe)
    ]
  end

  let(:default_probe_types_without_dap) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe),
      *foundational_flows_probe_types
    ]
  end

  let(:development_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
    ]
  end

  let(:amazon_q_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe)
    ]
  end

  let(:self_hosted_only_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe)
    ]
  end

  subject(:registry) { described_class.new(user) }

  def stub_feature_setting_selection(feature, payload)
    service = instance_double(Ai::FeatureSettingSelectionService)
    allow(Ai::FeatureSettingSelectionService)
      .to receive(:new).with(user, feature, nil).and_return(service)
    allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: payload))
  end

  def build_feature_setting(vendored: false)
    instance_double(Ai::FeatureSetting, vendored?: vendored)
  end

  def without_dap(probes)
    probes.reject { |probe| probe.is_a?(dap_probe_class) }
  end

  def dap_deployments(probes)
    probes.select { |probe| probe.is_a?(dap_probe_class) }.map do |probe|
      probe.send(:self_hosted?) ? :self_hosted : :cloud_connected
    end
  end

  before do
    stub_feature_setting_selection(:code_completions, nil)

    allow(::License).to receive(:current).and_return(license)
    allow(license).to receive(:offline_cloud_license?).and_return(offline_license)

    allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(self_hosted_dws_url)
  end

  describe 'Duo Agent Platform probe selection' do
    shared_examples 'selects Duo Agent Platform probes by deployment' do
      context 'when not on an offline license and no self-hosted DWS URL is set' do
        it 'includes only the cloud-connected probe' do
          expect(dap_deployments(probes)).to contain_exactly(:cloud_connected)
        end
      end

      context 'when a self-hosted DWS URL is configured' do
        let(:self_hosted_dws_url) { 'localhost:50052' }

        it 'includes both the cloud-connected and self-hosted probes' do
          expect(dap_deployments(probes)).to contain_exactly(:cloud_connected, :self_hosted)
        end
      end

      context 'when on an offline license' do
        let(:offline_license) { true }

        it 'excludes the cloud-connected probe' do
          expect(dap_deployments(probes)).to be_empty
        end

        context 'and a self-hosted DWS URL is configured' do
          let(:self_hosted_dws_url) { 'localhost:50052' }

          it 'includes only the self-hosted probe' do
            expect(dap_deployments(probes)).to contain_exactly(:self_hosted)
          end
        end
      end
    end

    context 'with default probes' do
      let(:probes) { registry.default_probes }

      it_behaves_like 'selects Duo Agent Platform probes by deployment'
    end

    context 'with self-hosted probes' do
      let(:probes) { registry.self_hosted_probes }

      it_behaves_like 'selects Duo Agent Platform probes by deployment'
    end
  end

  describe '#default_probes' do
    it 'returns the default probes alongside a single cloud-connected Duo Agent Platform probe' do
      expect(without_dap(registry.default_probes)).to match(default_probe_types_without_dap)
      expect(dap_deployments(registry.default_probes)).to eq([:cloud_connected])
    end
  end

  describe '#development_probes' do
    it 'returns the correct number and types of development probes' do
      expect(registry.development_probes).to match(development_probe_types)
    end
  end

  describe '#amazon_q_probes' do
    it 'returns the correct number and types of Amazon Q probes' do
      expect(registry.amazon_q_probes).to match(amazon_q_probe_types)
    end
  end

  describe '#self_hosted_probes' do
    context 'when no vendored feature setting and no instance model selection exists' do
      it 'returns the self-hosted-only probes followed by the foundational-flows probes' do
        expect(without_dap(registry.self_hosted_probes))
          .to match(self_hosted_only_probe_types + foundational_flows_probe_types)
      end
    end

    context 'when at least one vendored feature exists' do
      context 'with an Ai::FeatureSetting record' do
        before do
          create(:ai_feature_setting, feature: :code_completions, provider: :vendored)
        end

        context 'and code completions is vendored' do
          before do
            stub_feature_setting_selection(:code_completions, build_feature_setting(vendored: true))
          end

          it 'returns the default probes (minus DAP) combined with self-hosted-only probes' do
            expect(without_dap(registry.self_hosted_probes))
              .to match(default_probe_types_without_dap + self_hosted_only_probe_types)
          end
        end

        context 'and code completions is not vendored' do
          before do
            stub_feature_setting_selection(:code_completions, build_feature_setting(vendored: false))
          end

          it 'excludes EndToEndProbe' do
            expect(without_dap(registry.self_hosted_probes))
              .not_to include(an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe))
          end
        end
      end

      context 'with an Ai::ModelSelection::InstanceModelSelectionFeatureSetting record' do
        before do
          allow(::Ai::FeatureSetting).to receive_message_chain(:vendored, :exists?).and_return(false)
          allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting).to receive(:exists?).and_return(true)
        end

        it 'still routes through the vendored-features path' do
          expect(registry.self_hosted_probes)
            .to include(an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe))
        end
      end
    end
  end

  describe 'self-hosted billing probe selection' do
    let(:billing_probe_types) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingCustomersDotProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingCloudAiGatewayProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::BillingDuoWorkflowServiceProbe)
      ]
    end

    let(:billing_probe_classes) do
      [
        CloudConnector::StatusChecks::Probes::SelfHosted::BillingCustomersDotProbe,
        CloudConnector::StatusChecks::Probes::SelfHosted::BillingCloudAiGatewayProbe,
        CloudConnector::StatusChecks::Probes::SelfHosted::BillingDuoWorkflowServiceProbe
      ]
    end

    before do
      allow(license).to receive(:online_cloud_license?).and_return(online_cloud_license)
    end

    def billing_probes(probes)
      probes.select { |probe| billing_probe_classes.include?(probe.class) }
    end

    context 'when the license is online and a self-hosted DWS URL is set' do
      let(:online_cloud_license) { true }
      let(:self_hosted_dws_url) { 'localhost:50052' }

      it 'includes the billing probes exactly once in the default probes' do
        expect(billing_probes(registry.default_probes)).to match(billing_probe_types)
      end

      it 'includes the billing probes exactly once in the self-hosted probes' do
        expect(billing_probes(registry.self_hosted_probes)).to match(billing_probe_types)
      end

      context 'when at least one vendored feature exists' do
        before do
          create(:ai_feature_setting, feature: :code_completions, provider: :vendored)
        end

        it 'still includes the billing probes exactly once in the self-hosted probes' do
          expect(billing_probes(registry.self_hosted_probes)).to match(billing_probe_types)
        end
      end
    end

    context 'when the prerequisites are not met' do
      where(:online_cloud_license, :self_hosted_dws_url) do
        [
          [false, 'localhost:50052'],
          [true, nil],
          [false, nil]
        ]
      end

      with_them do
        it 'excludes the billing probes from both the default and self-hosted probes', :aggregate_failures do
          expect(billing_probes(registry.default_probes)).to be_empty
          expect(billing_probes(registry.self_hosted_probes)).to be_empty
        end
      end
    end
  end
end
