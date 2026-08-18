# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SelfHostedDapBilling, feature_category: :duo_agent_platform do
  describe '.self_hosted_dap_billing_enabled?' do
    subject { described_class.self_hosted_dap_billing_enabled? }

    context 'when running on GitLab.com (SaaS)', :saas do
      it { is_expected.to be_falsey }
    end

    context 'when using offline cloud license' do
      let(:license) { instance_double(License, online_cloud_license?: false) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to be_falsey }
    end

    context 'when there is no license' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it { is_expected.to be_falsey }
    end

    context 'when all conditions are met' do
      let(:license) { instance_double(License, online_cloud_license?: true) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to be_truthy }
    end

    context 'when in development environment and SELF_HOSTED_DAP_BILLING_ENABLED is not set' do
      before do
        allow(License).to receive(:current).and_return(nil)
        allow(Rails.env).to receive(:development?).and_return(true)
        stub_env('SELF_HOSTED_DAP_BILLING_ENABLED', nil)
      end

      it { is_expected.to be_falsey }
    end

    context 'when in development environment and SELF_HOSTED_DAP_BILLING_ENABLED is false' do
      before do
        allow(License).to receive(:current).and_return(nil)
        allow(Rails.env).to receive(:development?).and_return(true)
        stub_env('SELF_HOSTED_DAP_BILLING_ENABLED', 'false')
      end

      it { is_expected.to be_falsey }
    end

    context 'when in development environment and SELF_HOSTED_DAP_BILLING_ENABLED is true' do
      let(:license) { instance_double(License, online_cloud_license?: true) }

      before do
        allow(License).to receive(:current).and_return(license)
        allow(Rails.env).to receive(:development?).and_return(true)
        stub_env('SELF_HOSTED_DAP_BILLING_ENABLED', 'true')
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '.should_bill?' do
    subject(:should_bill) { described_class.should_bill?(feature_setting) }

    let_it_be(:model) { create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219') }
    let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model) }

    context 'when self_hosted_dap_billing_enabled? returns false' do
      before do
        allow(described_class).to receive(:self_hosted_dap_billing_enabled?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when feature setting is nil' do
      let(:feature_setting) { nil }

      before do
        allow(described_class).to receive(:self_hosted_dap_billing_enabled?).and_return(true)
      end

      it { is_expected.to be_falsey }
    end

    context 'when feature is not self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform_agentic_chat, provider: :vendored) }

      before do
        allow(described_class).to receive(:self_hosted_dap_billing_enabled?).and_return(true)
      end

      it { is_expected.to be_falsey }
    end

    context 'when billing is enabled and feature is self-hosted' do
      before do
        allow(described_class).to receive(:self_hosted_dap_billing_enabled?).and_return(true)
      end

      it { is_expected.to be_truthy }
    end
  end
end
