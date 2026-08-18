# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::Base, feature_category: :code_suggestions do
  let_it_be(:feature_setting_name) { 'code_generations' }
  let_it_be(:unit_primitive_name) { 'generate_code' }
  let_it_be(:user) { create(:user) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }

  let(:root_namespace) { nil }

  subject(:model_details) do
    described_class.new(current_user: user, feature_setting_name: feature_setting_name,
      unit_primitive_name: unit_primitive_name, root_namespace: root_namespace)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  shared_context 'with a default duo namespace assigned' do
    let(:default_namespace) { create(:group) }

    before do
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
    end
  end

  shared_examples "feature_setting cannot be inferred for method" do |details_method_name, default_value|
    let(:default_namespace) { nil }
    subject(:model_details_call) { model_details.send(details_method_name) }

    it 'returns nil' do
      expect(model_details_call).to eq default_value
    end
  end

  describe '#feature_setting' do
    context 'when the root_namespace is nil and there is no self-hosted feature setting' do
      it_behaves_like 'feature_setting cannot be inferred for method', :feature_setting, nil

      context 'when the user has a default duo namespace', :saas do
        include_context 'with a default duo namespace assigned' do
          it 'raises an DuoNamespaceUnassigned exception' do
            feature_setting = model_details.feature_setting

            expect(feature_setting.new_record?).to be_truthy
            expect(feature_setting.namespace).to eq(default_namespace)
            expect(feature_setting.feature).to eq(feature_setting_name)
            expect(feature_setting.offered_model_ref).to be_nil
          end
        end
      end
    end

    context 'when the feature is governed via self-hosted models' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: feature_setting_name, self_hosted_model: self_hosted_model)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'without a default duo namespace assigned' do
        it 'returns the feature setting' do
          expect(model_details.feature_setting).to eq(feature_setting)
        end
      end

      include_context 'with a default duo namespace assigned' do
        it 'returns the feature setting' do
          expect(model_details.feature_setting).to eq(feature_setting)
        end
      end
    end

    context 'when the feature is governed via model selection namespace feature setting', :saas do
      let(:root_namespace) { create(:group) }

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      before do
        root_namespace.add_developer(user)
      end

      it 'returns the feature setting' do
        expect(model_details.feature_setting).to eq(namespace_feature_setting)
      end
    end
  end

  describe '#namespace_feature_setting?' do
    subject(:namespace_feature_setting?) { model_details.namespace_feature_setting? }

    it_behaves_like 'feature_setting cannot be inferred for method', :namespace_feature_setting?, false

    context 'when the feature is governed via self-hosted models' do
      it 'returns false' do
        create(:ai_feature_setting, feature: feature_setting_name, self_hosted_model: self_hosted_model)

        expect(namespace_feature_setting?).to be(false)
      end
    end

    context 'when the feature is governed via model selection namespace feature setting', :saas do
      let!(:root_namespace) { create(:group) }
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      before do
        root_namespace.add_developer(user)
      end

      it 'returns true' do
        expect(namespace_feature_setting?).to be(true)
      end
    end
  end

  describe '#duo_context_not_found?' do
    let(:duo_default_required) { true }

    context 'when Amazon Q is connected' do
      it 'returns false' do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)

        expect(model_details.duo_context_not_found?).to be(false)
      end
    end

    context 'when AmazonQ is not connected' do
      before do
        expect_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:default_duo_namespace_required?).and_return(duo_default_required)
        end
      end

      context 'when no duo context can be found and it is required' do
        it_behaves_like 'feature_setting cannot be inferred for method', :duo_context_not_found?, true
      end

      context 'when no duo context can be found and it is not required' do
        let(:duo_default_required) { false }

        it 'returns false' do
          expect(model_details.duo_context_not_found?).to be(false)
        end
      end

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns false' do
          expect(model_details.duo_context_not_found?).to be(false)
        end
      end
    end
  end

  describe '#feature_disabled?' do
    subject(:feature_disabled?) { model_details.feature_disabled? }

    it_behaves_like 'feature_setting cannot be inferred for method', :feature_disabled?, false

    context 'when the feature is self-hosted, but set to disabled' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, provider: :disabled, feature: feature_setting_name)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns true' do
        expect(feature_disabled?).to be(true)
      end
    end

    context 'for model selection namespace feature setting', :saas do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns false' do
        expect(feature_disabled?).to be(false)
      end
    end
  end

  describe '#default?' do
    subject(:default?) { model_details.default? }

    context 'when the feature setting is nil' do
      it { is_expected.to be(true) }
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when the feature setting is self-hosted' do
        before do
          create(
            :ai_feature_setting,
            feature: feature_setting_name,
            self_hosted_model: self_hosted_model,
            provider: :self_hosted
          )
        end

        it { is_expected.to be(false) }
      end

      context 'when is set to vendored' do
        before do
          create(
            :ai_feature_setting,
            feature: feature_setting_name,
            self_hosted_model: nil,
            provider: :vendored
          )
        end

        it { is_expected.to be(true) }

        context 'when the instance level namespace is default' do
          before do
            create(:instance_model_selection_feature_setting, feature: feature_setting_name, offered_model_ref: nil)
          end

          it { is_expected.to be(true) }
        end

        context 'when the instance level namespace is not default' do
          before do
            create(:instance_model_selection_feature_setting,
              feature: feature_setting_name,
              offered_model_ref: 'claude_sonnet_3_5')
          end

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '#vendored?' do
    subject(:vendored?) { model_details.vendored? }

    it_behaves_like 'feature_setting cannot be inferred for method', :vendored?, false

    context 'when the feature is self-hosted, but set to vendored' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, provider: :vendored, feature: feature_setting_name)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns true' do
        expect(vendored?).to be(true)
      end
    end

    context 'when the feature is governed via self-hosted models' do
      it 'returns false' do
        create(:ai_feature_setting, feature: feature_setting_name, self_hosted_model: self_hosted_model)

        expect(vendored?).to be(false)
      end
    end

    context 'for namespace feature setting', :saas do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns false' do
        expect(vendored?).to be(false)
      end
    end
  end

  describe '#base_url' do
    it_behaves_like 'feature_setting cannot be inferred for method', :base_url, 'https://cloud.gitlab.com/ai'

    context 'when the feature is governed via self-hosted models' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored) }

      it 'takes the base url from feature settings' do
        url = "http://localhost:5000"
        expect(::Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(url)

        expect(model_details.base_url).to eq(url)
      end
    end

    context 'when the feature is governed via model selection namespace feature setting', :saas do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns correct URL' do
        expect(model_details.base_url).to eql('https://cloud.gitlab.com/ai')
      end
    end
  end

  describe '#unit_primitive_name' do
    it 'matches the initializer argument' do
      expect(model_details.unit_primitive_name).to eq(unit_primitive_name)
    end
  end

  context 'when Amazon Q is connected' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

    before do
      stub_licensed_features(amazon_q: true)
      Ai::Setting.for_organization(user.organization).update!(amazon_q_ready: true)
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
    end

    it 'returns correct feature name and licensed feature' do
      expect(model_details.feature_name).to eq(:amazon_q_integration)
      expect(model_details.licensed_feature).to eq(:amazon_q)
    end

    describe '#unit_primitive_name' do
      it 'is amazon_q_integration' do
        expect(model_details.unit_primitive_name).to eq(:amazon_q_integration)
      end
    end
  end
end
