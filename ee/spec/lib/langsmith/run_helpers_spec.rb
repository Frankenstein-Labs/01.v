# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Langsmith::RunHelpers, :aggregate_failures, feature_category: :ai_evaluation do
  let(:enabled) { true }

  let(:ai_class) do
    Class.new do
      include Langsmith::RunHelpers

      def build_prompt(question:)
        "Human: #{question}"
      end
      traceable :build_prompt, name: 'Build prompt', run_type: 'prompt'
    end
  end

  let(:run_id) { '12345' }

  before do
    stub_env('LANGCHAIN_TRACING_V2', enabled.to_s)
  end

  shared_examples_for 'sends a run to Langsmith client' do
    let(:expected_outputs) { { "result" => "\"Human: How are you?\"" } }
    let(:expected_kwargs) { { question: "How are you?" }.to_s }
    let(:error) { '' }

    it 'sends a run to Langsmith client' do
      allow(SecureRandom).to receive(:uuid).and_return(run_id)

      expect_next_instance_of(Langsmith::Client) do |client|
        expect(client).to receive(:post_run).with(
          run_id: run_id,
          name: 'Build prompt',
          run_type: 'prompt',
          inputs: hash_including(
            "method" => hash_including(
              { "kwargs" => expected_kwargs }
            )
          ),
          parent_id: nil,
          extra: anything,
          tags: anything
        )

        expect(client).to receive(:patch_run).with(
          run_id: run_id,
          outputs: expected_outputs,
          error: /#{error}/
        )
      end

      execute_method
    end
  end

  it_behaves_like 'sends a run to Langsmith client' do
    let(:execute_method) { ai_class.new.build_prompt(question: 'How are you?') }
  end

  context 'when tracing is disabled' do
    let(:enabled) { false }

    it 'does not send a run to Langsmith client' do
      expect(Langsmith::Client).not_to receive(:new)

      ai_class.new.build_prompt(question: 'How are you?')
    end
  end

  context 'when production environment' do
    before do
      allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
    end

    it 'does not send a run to Langsmith client' do
      expect(Langsmith::Client).not_to receive(:new)

      ai_class.new.build_prompt(question: 'How are you?')
    end
  end

  context 'when an error is raised in the method' do
    let(:ai_class) do
      Class.new do
        extend Langsmith::RunHelpers

        def self.build_prompt(question:) # rubocop:disable Lint/UnusedMethodArgument -- this is a test
          raise ArgumentError
        end
        traceable :build_prompt, name: 'Build prompt', run_type: 'prompt', class_method: true
      end
    end

    it_behaves_like 'sends a run to Langsmith client' do
      let(:execute_method) do
        ai_class.build_prompt(question: 'How are you?') rescue nil # rubocop:disable Style/RescueModifier -- this is a test
      end

      let(:error) { 'ArgumentError' }
      let(:expected_outputs) { { "result" => "nil" } }
    end
  end

  context 'with class method' do
    let(:ai_class) do
      Class.new do
        extend Langsmith::RunHelpers

        def self.build_prompt(question:)
          "Human: #{question}"
        end
        traceable :build_prompt, name: 'Build prompt', run_type: 'prompt', class_method: true
      end
    end

    it_behaves_like 'sends a run to Langsmith client' do
      let(:execute_method) { ai_class.build_prompt(question: 'How are you?') }
    end
  end

  describe '.enabled?' do
    subject { described_class.enabled? }

    it { is_expected.to be(true) }

    context 'when tracing is disabled' do
      let(:enabled) { false }

      it { is_expected.to be(false) }
    end

    context 'when production environment' do
      before do
        allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.to_headers' do
    subject(:headers) { described_class.to_headers }

    before do
      allow_next_instance_of(Langsmith::Client) do |client|
        allow(client).to receive(:post_run)
        allow(client).to receive(:patch_run)
      end
    end

    it 'return langsmith headers' do
      ai_class.new.build_prompt(question: 'How are you?')

      expect(headers).to include('langsmith-trace' => an_instance_of(String))
    end
  end
end
