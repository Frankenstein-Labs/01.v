# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::Concerns::GitlabDefaultModelParams, feature_category: :"self-hosted_models" do
  let(:test_class) do
    Class.new do
      include Ai::ModelSelection::Concerns::GitlabDefaultModelParams

      # Make private method accessible for testing
      def test_params_as_if_gitlab_default_model(feature_name)
        params_as_if_gitlab_default_model(feature_name)
      end
    end
  end

  let(:test_instance) { test_class.new }

  describe 'constants' do
    describe 'MODEL_PROVIDER' do
      it 'is set to gitlab' do
        expect(described_class::MODEL_PROVIDER).to eq('gitlab')
      end
    end

    describe 'IDENTIFIER_FOR_DEFAULT_MODEL' do
      it 'is set to an empty string' do
        expect(described_class::IDENTIFIER_FOR_DEFAULT_MODEL).to eq('')
      end
    end
  end

  describe '#params_as_if_gitlab_default_model' do
    subject(:params) { test_instance.test_params_as_if_gitlab_default_model(feature_name) }

    context 'when feature_name is code_completions' do
      let(:feature_name) { :code_completions }

      it 'returns expected hash' do
        expect(params).to eq(
          model_name: described_class::IDENTIFIER_FOR_DEFAULT_MODEL,
          model_provider: described_class::MODEL_PROVIDER
        )
      end
    end

    context 'when feature_name is not code_completions' do
      let(:feature_name) { :duo_chat }

      it 'returns expected hash' do
        expect(params).to eq(
          provider: described_class::MODEL_PROVIDER,
          identifier: described_class::IDENTIFIER_FOR_DEFAULT_MODEL,
          feature_setting: feature_name.to_s
        )
      end
    end
  end
end
