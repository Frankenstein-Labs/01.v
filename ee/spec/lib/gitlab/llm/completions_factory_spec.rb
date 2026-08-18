# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::CompletionsFactory, feature_category: :ai_abstraction_layer do
  describe ".completion!" do
    let(:prompt_message) { build(:ai_message, ai_action: completion_name) }
    let(:service_class) { Class.new }
    let(:aigw_service_class) { Class.new }
    let(:prompt_class) { Class.new }
    let(:params) { {} }
    let(:features) do
      {
        my_feature: {
          service_class: service_class,
          prompt_class: prompt_class
        },
        my_migrated_feature: {
          service_class: service_class,
          aigw_service_class: aigw_service_class,
          prompt_class: prompt_class
        }
      }
    end

    before do
      stub_const('::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST', features)
    end

    subject(:completion) { described_class.completion!(prompt_message, params) }

    context 'with existing completion' do
      let(:completion_dobule) { instance_double(Gitlab::Llm::Completions::Base) }
      let(:completion_name) { :my_feature }
      let(:expected_params) { { action: completion_name }.merge(params) }
      let(:expected_service_class) { service_class }

      shared_examples 'returning completion' do
        it 'returns completion' do
          expect(expected_service_class).to receive(:new).with(prompt_message, prompt_class, expected_params)
            .and_return(completion_dobule)

          expect(completion).to be(completion_dobule)
        end
      end

      it_behaves_like 'returning completion'

      context 'with params' do
        let(:params) { { include_source_code: true } }

        it_behaves_like 'returning completion'
      end

      context 'when the service has an AI Gateway service class' do
        let(:completion_name) { :my_migrated_feature }

        before do
          stub_feature_flag_definition(:prompt_migration_my_migrated_feature)
        end

        it_behaves_like 'returning completion' do
          let(:expected_service_class) { aigw_service_class }
        end

        context 'when prompt_migration_my_migrated_feature is disabled' do
          before do
            stub_feature_flags(prompt_migration_my_migrated_feature: false)
          end

          it_behaves_like 'returning completion'
        end
      end
    end

    context 'with invalid completion' do
      let(:completion_name) { :invalid_name }

      it 'raises name error completion service' do
        expect { completion }.to raise_error(NameError, "completion class for action invalid_name not found")
      end
    end
  end
end
