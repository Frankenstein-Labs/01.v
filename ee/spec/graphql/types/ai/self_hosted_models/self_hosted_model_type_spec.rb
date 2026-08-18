# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiSelfHostedModel'], feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'abc123') }
  let_it_be(:feature_setting) { create(:ai_feature_setting, self_hosted_model: self_hosted_model) }

  let(:fields) do
    %w[
      id
      name
      model
      model_display_name
      endpoint
      identifier
      has_api_token
      feature_settings
      release_state
    ]
  end

  it { expect(described_class).to have_graphql_fields(fields).at_least }

  describe 'fields' do
    it 'returns the correct values' do
      expect(resolve_field(:id, self_hosted_model)).to eq(self_hosted_model.to_gid)
      expect(resolve_field(:name, self_hosted_model)).to eq('mistral-7b-ollama-api')
      expect(resolve_field(:model, self_hosted_model)).to eq('mistral')
      expect(resolve_field(:model_display_name, self_hosted_model)).to eq('Mistral')
      expect(resolve_field(:endpoint, self_hosted_model)).to eq('http://localhost:11434/v1')
      expect(resolve_field(:identifier, self_hosted_model)).to eq('provider/some-model')
      expect(resolve_field(:has_api_token, self_hosted_model)).to be(true)
      expect(resolve_field(:feature_settings, self_hosted_model)).to include(feature_setting)
      expect(resolve_field(:release_state, self_hosted_model)).to eq('ga')
    end

    describe 'release_state' do
      let(:self_hosted_beta_model) { create(:ai_self_hosted_model, name: 'beta model', model: :deepseekcoder) }

      it 'returns correct state when model is in beta' do
        expect(resolve_field(:release_state, self_hosted_beta_model)).to eq('beta')
      end
    end
  end
end
