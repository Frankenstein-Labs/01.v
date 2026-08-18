# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Evaluators::Base, feature_category: :ai_evaluation do
  let(:user) { build_stubbed(:user) }
  let(:tracking_context) do
    {
      request_id: SecureRandom.uuid,
      action: 'base_spec'
    }
  end

  let(:options) { {} }

  describe 'interface' do
    subject(:instance) { described_class.new(user:, tracking_context:, options:) }

    it 'expects subclasses to implement abstract methods' do
      aggregate_failures do
        expect { instance.execute }.to raise_error(NotImplementedError)
        expect { instance.send(:unit_primitive_name) }.to raise_error(NotImplementedError)
        expect { instance.send(:model_metadata, user) }.to raise_error(NotImplementedError)
        expect { instance.send(:prompt_name) }.to raise_error(NotImplementedError)
        expect { instance.send(:prompt_version) }.to raise_error(NotImplementedError)
        expect { instance.send(:inputs) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe '#execute' do
    subject(:evaluation_response) { base_evaluator.new(user:, tracking_context:, options:).execute }

    let(:base_evaluator) do
      Class.new(Gitlab::Llm::Evaluators::Base) do
        def unit_primitive_name
          :review_merge_request
        end

        def model_metadata(_user)
          {
            provider: 'gitlab',
            feature_setting: 'review_merge_request'
          }
        end

        def prompt_name
          'review_merge_request'
        end

        def prompt_version
          '1.2.3'
        end

        def inputs
          {
            one: 1,
            two: 2
          }
        end
      end
    end

    let(:evaluation_raw_response_body) { 'raw_response' }

    let(:evaluation_raw_response) do
      instance_double(HTTParty::Response, body: { content: evaluation_raw_response_body }.to_json, success?: true)
    end

    before do
      allow_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
        allow(client).to receive(:complete_prompt).and_return(evaluation_raw_response)
      end
    end

    it 'executes the AI gateway request' do
      expect(evaluation_response).to eq(evaluation_raw_response_body)
    end
  end
end
