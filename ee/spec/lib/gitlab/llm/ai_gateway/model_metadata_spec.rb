# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ModelMetadata, feature_category: :ai_abstraction_layer do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:self_hosted_feature_setting) { create(:ai_feature_setting, self_hosted_model: self_hosted_model) }
  let(:feature_setting) { self_hosted_feature_setting }
  let(:model_metadata) { described_class.new(feature_setting: feature_setting) }

  before do
    stub_current_organization(organization)
  end

  describe '#to_params' do
    subject(:to_params) { model_metadata.to_params }

    context 'when feature_setting is self-hosted' do
      it 'returns self-hosted params' do
        is_expected.to eq({
          provider: :openai,
          name: self_hosted_model.model,
          endpoint: self_hosted_model.endpoint,
          api_key: self_hosted_model.api_token,
          identifier: self_hosted_model.identifier
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is connected' do
      let(:feature_setting) { nil }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        ::Ai::Setting.for_organization(organization).update!(amazon_q_role_arn: "role-arn")
      end

      it 'returns amazon_q params' do
        is_expected.to eq({
          provider: :amazon_q,
          name: :amazon_q,
          role_arn: "role-arn"
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is not connected' do
      let(:feature_setting) { nil }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
      end

      it { is_expected.to be_nil }
    end

    context 'when feature_setting is a NamespaceFeatureSetting' do
      let_it_be(:root_namespace) { create(:group) }

      let(:feature_name) { 'duo_chat' }
      let(:model_ref) { 'claude-3-7-sonnet-20250219' }

      let(:feature_setting) do
        create(
          :ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_name,
          offered_model_ref: model_ref
        )
      end

      it 'returns the correct namespace_settings_params' do
        is_expected.to eq({
          provider: 'gitlab',
          identifier: model_ref,
          feature_setting: 'duo_chat'
        })
      end
    end
  end
end
