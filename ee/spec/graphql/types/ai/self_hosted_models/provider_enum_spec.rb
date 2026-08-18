# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiSelfHostedModelProvider'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiSelfHostedModelProvider') }

  describe 'self-hosted model provider' do
    using RSpec::Parameterized::TableSyntax

    where(:provider_name, :provider_value) do
      'API'       | 'api'
      'BEDROCK'   | 'bedrock'
      'VERTEX_AI' | 'vertex_ai'
    end

    with_them do
      it 'exposes the provider with the correct value' do
        expect(described_class.values[provider_name].value).to eq(provider_value)
      end
    end
  end
end
