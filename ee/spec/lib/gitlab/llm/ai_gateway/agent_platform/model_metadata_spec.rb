# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata, feature_category: :duo_agent_platform do
  let(:feature_setting) { build(:ai_feature_setting, :duo_agent_platform) }
  let(:service) { described_class.new(feature_setting: feature_setting) }

  describe '#initialize' do
    it 'sets the feature_setting' do
      expect(service.send(:feature_setting)).to eq(feature_setting)
    end

    it 'allows nil feature_setting' do
      service = described_class.new(feature_setting: nil)
      expect(service.send(:feature_setting)).to be_nil
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    it 'creates ModelMetadata with the provided feature_setting' do
      allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
        allow(metadata).to receive(:to_params).and_return({ provider: :gitlab })
      end

      expect(::Gitlab::Llm::AiGateway::ModelMetadata).to receive(:new)
        .with(feature_setting: feature_setting)
        .and_call_original

      execute
    end

    context 'when ModelMetadata returns blank values' do
      where(:blank_value) do
        [nil, {}, [], '', '   ', false]
      end

      with_them do
        before do
          allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
            allow(metadata).to receive(:to_params).and_return(blank_value)
          end
        end

        it 'returns {} for blank values' do
          expect(execute).to eq({})
        end
      end
    end

    context 'when ModelMetadata returns valid data' do
      let(:model_metadata) do
        {
          provider: 'gitlab',
          name: 'claude-3-sonnet',
          identifier: 'claude-3-7-sonnet-20250219'
        }
      end

      before do
        allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
          allow(metadata).to receive(:to_params).and_return(model_metadata)
        end
      end

      it 'returns model metadata header with JSON serialized data' do
        expect(execute).to eq({
          'x-gitlab-agent-platform-model-metadata' => model_metadata.to_json
        })
      end
    end

    context 'with different types of valid model metadata' do
      it 'serializes minimal metadata correctly' do
        test_data = { provider: 'gitlab' }

        allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
          allow(metadata).to receive(:to_params).and_return(test_data)
        end

        expect(execute).to eq({
          'x-gitlab-agent-platform-model-metadata' => test_data.to_json
        })
      end

      it 'serializes complete gitlab metadata correctly' do
        test_data = {
          provider: 'gitlab',
          name: 'claude-3-sonnet',
          identifier: 'claude-3-7-sonnet-20250219',
          feature_setting: 'duo_agent_platform'
        }

        allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
          allow(metadata).to receive(:to_params).and_return(test_data)
        end

        expect(execute).to eq({
          'x-gitlab-agent-platform-model-metadata' => test_data.to_json
        })
      end

      it 'serializes self-hosted metadata correctly' do
        test_data = {
          provider: 'self_hosted',
          name: 'mistral-7b',
          endpoint: 'http://localhost:11434/v1',
          api_key: 'secret-key',
          identifier: 'mistral/mistral-7b'
        }

        allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
          allow(metadata).to receive(:to_params).and_return(test_data)
        end

        expect(execute).to eq({
          'x-gitlab-agent-platform-model-metadata' => test_data.to_json
        })
      end
    end

    context 'when feature_setting is nil' do
      let(:service) { described_class.new(feature_setting: nil) }

      it 'passes nil to ModelMetadata and returns {} when metadata is blank' do
        allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
          allow(metadata).to receive(:to_params).and_return(nil)
        end

        expect(::Gitlab::Llm::AiGateway::ModelMetadata).to receive(:new)
          .with(feature_setting: nil)
          .and_call_original

        result = execute
        expect(result).to eq({})
      end
    end

    context 'with error handling' do
      context 'when ModelMetadata raises an exception' do
        before do
          allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
            allow(metadata).to receive(:to_params).and_raise(StandardError, 'Model metadata error')
          end
        end

        it 'lets the exception bubble up' do
          expect { execute }.to raise_error(StandardError, 'Model metadata error')
        end
      end

      context 'when ModelMetadata initialization raises an exception' do
        before do
          allow(::Gitlab::Llm::AiGateway::ModelMetadata).to receive(:new)
            .and_raise(ArgumentError, 'Invalid feature setting')
        end

        it 'lets the exception bubble up' do
          expect { execute }.to raise_error(ArgumentError, 'Invalid feature setting')
        end
      end

      context 'when JSON serialization fails' do
        let(:invalid_data) { instance_double(Object, present?: true) }

        before do
          allow(invalid_data).to receive(:to_json).and_raise(JSON::GeneratorError, 'Invalid JSON')

          allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
            allow(metadata).to receive(:to_params).and_return(invalid_data)
          end
        end

        it 'lets the JSON error bubble up' do
          expect { execute }.to raise_error(JSON::GeneratorError, 'Invalid JSON')
        end
      end
    end
  end

  describe 'return value consistency' do
    it 'returns a hash with or without metadata' do
      # Test with valid data
      allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
        allow(metadata).to receive(:to_params).and_return({ provider: :gitlab })
      end

      result = service.execute
      expect(result).to be_a(Hash)

      # Test with empty data
      allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
        allow(metadata).to receive(:to_params).and_return(nil)
      end

      result = service.execute
      expect(result).to eq({})
    end

    it 'returns expected header key when data is present' do
      allow_next_instance_of(::Gitlab::Llm::AiGateway::ModelMetadata) do |metadata|
        allow(metadata).to receive(:to_params).and_return({ provider: :gitlab })
      end

      result = service.execute
      expect(result.keys).to eq(['x-gitlab-agent-platform-model-metadata'])
      expect(result['x-gitlab-agent-platform-model-metadata']).to be_a(String)
      expect(::Gitlab::Json.parse(result['x-gitlab-agent-platform-model-metadata'])).to eq({ 'provider' => 'gitlab' })
    end
  end

  describe 'integration behavior' do
    it 'flows through the complete happy path' do
      expected_metadata = {
        provider: 'gitlab',
        identifier: 'claude-3-7-sonnet-20250219',
        feature_setting: 'duo_agent_platform'
      }

      expect(::Gitlab::Llm::AiGateway::ModelMetadata).to receive(:new)
        .with(feature_setting: feature_setting)
        .and_return(instance_double(
          ::Gitlab::Llm::AiGateway::ModelMetadata,
          to_params: expected_metadata
        ))

      result = service.execute

      expect(result).to eq({
        'x-gitlab-agent-platform-model-metadata' => expected_metadata.to_json
      })

      parsed_result = ::Gitlab::Json.parse(result['x-gitlab-agent-platform-model-metadata'])
      expect(parsed_result).to eq(expected_metadata.deep_stringify_keys)
    end
  end
end
