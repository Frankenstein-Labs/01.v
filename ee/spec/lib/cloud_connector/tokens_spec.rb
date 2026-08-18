# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Tokens, feature_category: :system_access do
  describe '.get' do
    let(:resource) { build(:user) }
    let(:token_string) { 'ABCDEF' }
    let(:extra_claims) { {} }
    let(:feature_setting) { nil }

    subject(:encoded_token) do
      described_class.get(
        unit_primitive: unit_primitive,
        resource: resource,
        extra_claims: extra_claims,
        feature_setting: feature_setting
      )
    end

    before do
      # "Defuse" all counter calls so as not to pollute the tmp folder with metric data.
      allow(::Gitlab::Metrics).to receive(:counter).and_return(Gitlab::Metrics::NullMetric.instance)
    end

    shared_examples 'uses TokenLoader to obtain a token' do
      let(:token_provider) { instance_double(described_class::TokenLoader, token: token_string) }

      before do
        allow(described_class::TokenLoader).to receive(:new).and_return(token_provider)
      end

      it 'returns the token from TokenLoader' do
        expect(encoded_token).to eq(token_string)
      end
    end

    shared_examples 'uses self-signed path' do
      let_it_be(:jwk) { build(:cloud_connector_keys).to_jwk }
      let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed, :active) }

      before do
        allow_next_instance_of(described_class::TokenIssuer) do |issuer|
          allow(issuer).to receive(:token).and_return(token_string)
        end

        allow(CloudConnector::CachingKeyLoader).to receive(:private_jwk).and_return(jwk)
      end

      it 'returns a self-signed token' do
        expect(encoded_token).to eq(token_string)
      end
    end

    context 'when self-signed tokens are globally enabled via SaaS feature flag' do
      before do
        stub_saas_features(cloud_connector_self_signed_tokens: true)
      end

      let(:unit_primitive) { :complete_code }

      it_behaves_like 'uses self-signed path'

      context 'with nil unit primitive' do
        let(:unit_primitive) { nil }

        it_behaves_like 'uses self-signed path'
      end

      context 'with real add-on purchase for duo_pro', :with_cloud_connector do
        let_it_be(:cloud_connector_key) { create(:cloud_connector_keys) }
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed, :active)
        end

        let(:resource) { :instance }

        it 'includes unit primitive scope when add-on name is normalized from code_suggestions to duo_pro' do
          token = described_class.get(unit_primitive: unit_primitive, resource: resource)
          decoded = JWT.decode(token, nil, false).first

          expect(decoded['scopes']).to include('complete_code')
        end
      end
    end

    context 'when feature_setting is self_hosted' do
      let(:unit_primitive) { :invalid_unit_primitive }
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :code_generations, provider: :self_hosted) }

      it_behaves_like 'uses self-signed path'
    end

    context 'when unit_primitive is :self_hosted_models' do
      let(:unit_primitive) { :self_hosted_models }

      it_behaves_like 'uses self-signed path'
    end

    context 'when self_hosted model is configured for the feature' do
      let(:unit_primitive) { :observability_all }

      before do
        feature_obj = instance_double(Ai::FeatureSetting, self_hosted?: true)
        allow(Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(unit_primitive).and_return(feature_obj)
      end

      it_behaves_like 'uses self-signed path'
    end

    context 'when environment variable is set' do
      let(:unit_primitive) { :observability_all }

      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'true')
      end

      it_behaves_like 'uses self-signed path'
    end

    context 'when none of the self-signing conditions are met' do
      context 'and feature_for_unit_primitive returns nil' do
        let(:unit_primitive) { :observability_all }

        before do
          allow(Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(unit_primitive).and_return(nil)
        end

        it_behaves_like 'uses TokenLoader to obtain a token'
      end

      context 'and feature_setting is not self_hosted' do
        let(:unit_primitive) { :observability_all }
        let(:feature_setting) { instance_double(Ai::FeatureSetting, self_hosted?: false) }

        before do
          allow(Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(unit_primitive).and_return(nil)
        end

        it_behaves_like 'uses TokenLoader to obtain a token'
      end

      context 'and unit_primitive is unknown' do
        let(:unit_primitive) { :unknown }

        it_behaves_like 'uses TokenLoader to obtain a token'
      end
    end
  end

  describe '.cloud_connector_token' do
    it 'delegates to TokenLoader and returns its token' do
      token_string = 'ABCDEF'
      token_provider = instance_double(described_class::TokenLoader, token: token_string)

      allow(described_class::TokenLoader).to receive(:new).and_return(token_provider)

      expect(described_class.cloud_connector_token).to eq(token_string)
    end
  end
end
