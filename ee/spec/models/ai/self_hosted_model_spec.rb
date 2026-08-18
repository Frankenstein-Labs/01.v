# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SelfHostedModel, feature_category: :"self-hosted_models" do
  using RSpec::Parameterized::TableSyntax

  describe 'validation' do
    subject(:self_hosted_model) { build(:ai_self_hosted_model) }

    it { is_expected.to validate_presence_of(:model) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:identifier).is_at_most(255) }

    describe 'endpoint' do
      context 'for API provided models' do
        it { is_expected.not_to allow_value(nil).for(:endpoint) }
        it { is_expected.to allow_value('http://gitlab.com/s').for(:endpoint) }
        it { is_expected.not_to allow_value('javascript:alert(1)').for(:endpoint) }
      end

      context 'for cloud provided models' do
        where(:provider) { [:bedrock, :vertex_ai] }

        with_them do
          subject(:self_hosted_model) { build(:ai_self_hosted_model, provider: provider, endpoint: nil) }

          it { is_expected.to allow_value(nil).for(:endpoint) }
        end
      end
    end

    describe '.ga_models' do
      let_it_be(:beta_model) { create(:ai_self_hosted_model, name: 'Beta model', model: :codellama) }
      let_it_be(:ga_model) { create(:ai_self_hosted_model, name: 'GA model', model: :mistral) }

      it { expect(described_class.ga_models).not_to include(beta_model) }
      it { expect(described_class.ga_models).to match_array([ga_model]) }
    end

    describe '.allowed_models_with_family', :aggregate_failures do
      let_it_be(:ga_model_mistral) { create(:ai_self_hosted_model, name: 'GA model', model: :mistral) }
      let_it_be(:beta_model_codellama) { create(:ai_self_hosted_model, name: 'Beta model', model: :codellama) }

      context 'when testing terms have been accepted' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
        end

        it 'returns existing models for GA and BETA model families' do
          expect(described_class.allowed_models_with_family(:mistral)).to eq([ga_model_mistral])
          expect(described_class.allowed_models_with_family(:codellama)).to eq([beta_model_codellama])
          expect(described_class.allowed_models_with_family(:codestral)).to be_empty
        end
      end

      context 'when testing terms have not been accepted' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
        end

        it 'returns existing models for GA model families' do
          expect(described_class.allowed_models_with_family(:mistral)).to eq([ga_model_mistral])
          expect(described_class.allowed_models_with_family(:codellama)).to be_empty
          expect(described_class.allowed_models_with_family(:codestral)).to be_empty
        end
      end
    end

    describe '#api_token' do
      let(:token) { 'random_token' }

      it 'ensures that it encrypts api tokens' do
        self_hosted_model.api_token = token
        self_hosted_model.save!

        expect(self_hosted_model.persisted?).to be_truthy
        expect(self_hosted_model.reload.api_token).to eq(token)
        expect(self_hosted_model.reload.encrypted_api_token).not_to include(token)
      end
    end

    describe '#identifier' do
      subject(:self_hosted_model) { build(:ai_self_hosted_model, identifier: nil) }

      it 'coerces null values to empty string' do
        expect(self_hosted_model.identifier).to eq('')
      end
    end

    describe '#model_ref' do
      context 'when an identifier is present' do
        subject(:self_hosted_model) { build(:ai_self_hosted_model, model: :mistral, identifier: 'mistral-7b') }

        it 'returns the identifier' do
          expect(self_hosted_model.model_ref).to eq('mistral-7b')
        end
      end

      context 'when the identifier is blank' do
        subject(:self_hosted_model) { build(:ai_self_hosted_model, model: :mistral, identifier: '') }

        it 'falls back to the model enum value' do
          expect(self_hosted_model.model_ref).to eq('mistral')
        end
      end
    end

    describe '#to_model_selection' do
      subject(:self_hosted_model) do
        build(:ai_self_hosted_model, name: 'My Mistral', model: :mistral, identifier: 'mistral-7b')
      end

      it 'returns the ref and name' do
        expect(self_hosted_model.to_model_selection).to eq({ ref: 'mistral-7b', name: 'My Mistral' })
      end
    end

    describe '#release_state' do
      Ai::SelfHostedModel::MODELS_RELEASE_STATE.each do |model, expected_state|
        context "when model is #{model}" do
          subject(:self_hosted_model) { build(:ai_self_hosted_model, model: model) }

          it "returns #{expected_state}" do
            expect(self_hosted_model.release_state).to eq(expected_state)
          end
        end
      end

      context 'when model is not listed in MODELS_RELEASE_STATE' do
        subject(:self_hosted_model) { build(:ai_self_hosted_model, model: nil) }

        it 'returns EXPERIMENTAL as default release state' do
          expect(self_hosted_model.release_state).to eq(Ai::SelfHostedModel::RELEASE_STATE_EXPERIMENTAL)
        end
      end
    end

    describe '#ga?' do
      it 'returns true if the model is in GA' do
        expect(self_hosted_model.ga?).to be(true)
      end
    end

    describe 'provider enum' do
      it { is_expected.to define_enum_for(:provider).with_values(api: 0, bedrock: 1, vertex_ai: 2) }

      it 'defaults to api' do
        expect(described_class.new.provider).to eq('api')
      end
    end

    describe '#unsupported_family_for_duo_agent_platform_code_review?' do
      subject { build(:ai_self_hosted_model, model: model).unsupported_family_for_duo_agent_platform_code_review? }

      where(:model, :expected) do
        :gpt           | false
        :general       | false
        :claude_3      | false
        :mistral       | true
        :llama3        | true
        :codegemma     | true
        :codestral     | true
        :codellama     | true
        :deepseekcoder | true
        :mixtral       | true
        :embedding     | true
      end

      with_them do
        it { is_expected.to eq(expected) }
      end
    end
  end
end
