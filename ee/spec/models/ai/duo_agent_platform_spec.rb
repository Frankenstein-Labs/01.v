# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoAgentPlatform, feature_category: :duo_code_review do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:container) { project }
  let(:duo_features_enabled) { true }
  let(:user_allowed_to_use_duo_agent_platform) { true }

  before do
    allow(container).to receive(:duo_features_enabled).and_return(duo_features_enabled)

    allow(user).to receive(:allowed_to_use?)
      .with(:duo_agent_platform, root_namespace: group)
      .and_return(user_allowed_to_use_duo_agent_platform)

    allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: nil))
    end
  end

  describe '.configured?' do
    subject(:configured) { described_class.configured?(user: user, container: container) }

    context 'when duo_features_enabled is false' do
      let(:duo_features_enabled) { false }

      it { is_expected.to be(false) }
    end

    context 'when SaaS or self-managed using cloud-connected models' do
      it { is_expected.to be(true) }
    end

    context 'when self-managed using a non-self-hosted feature setting' do
      before do
        feature_setting = instance_double(::Ai::FeatureSetting, self_hosted?: false)
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
        end
      end

      it { is_expected.to be(true) }
    end

    context 'when self-managed using self-hosted models' do
      let(:self_hosted_model) { instance_double(::Ai::SelfHostedModel) }
      let(:feature_setting) do
        instance_double(::Ai::FeatureSetting, self_hosted?: true, self_hosted_model: self_hosted_model)
      end

      before do
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
        end
      end

      context 'with an incompatible model family' do
        before do
          allow(self_hosted_model)
            .to receive(:unsupported_family_for_duo_agent_platform_code_review?)
            .and_return(true)
        end

        it { is_expected.to be(false) }
      end

      context 'with a compatible model family' do
        before do
          allow(self_hosted_model)
            .to receive(:unsupported_family_for_duo_agent_platform_code_review?)
            .and_return(false)
        end

        context 'when no self-hosted DWS URL is configured' do
          before do
            allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
          end

          it { is_expected.to be(false) }
        end

        context 'when a self-hosted DWS URL is configured' do
          before do
            allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('https://dws.example.com')
          end

          it { is_expected.to be(true) }
        end
      end

      context 'without a self-hosted model' do
        let(:feature_setting) do
          instance_double(::Ai::FeatureSetting, self_hosted?: true, self_hosted_model: nil)
        end

        before do
          allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.available?' do
    subject(:available) { described_class.available?(user: user, container: container) }

    context 'when not configured' do
      let(:duo_features_enabled) { false }

      it { is_expected.to be(false) }
    end

    context 'when configured' do
      context 'and the user is allowed to use duo_agent_platform' do
        it { is_expected.to be(true) }
      end

      context 'and the user is not allowed to use duo_agent_platform' do
        let(:user_allowed_to_use_duo_agent_platform) { false }

        it { is_expected.to be(false) }
      end
    end
  end
end
