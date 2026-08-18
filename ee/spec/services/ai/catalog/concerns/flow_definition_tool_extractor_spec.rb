# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Concerns::FlowDefinitionToolExtractor, feature_category: :workflow_catalog do
  let(:test_class) do
    Class.new do
      include Ai::Catalog::Concerns::FlowDefinitionToolExtractor

      def extract(definition)
        extract_tools_from_flow_definition(definition)
      end
    end
  end

  subject(:extracted) { test_class.new.extract(definition) }

  describe '#extract_tools_from_flow_definition' do
    context 'when definition is nil' do
      let(:definition) { nil }

      it { is_expected.to eq([]) }
    end

    context 'when definition has no components' do
      let(:definition) { { 'version' => 'v1' } }

      it { is_expected.to eq([]) }
    end

    context 'when components have toolset entries' do
      let(:definition) do
        {
          'components' => [
            { 'name' => 'planner', 'type' => 'AgentComponent',
              'toolset' => ['read_file', { 'create_merge_request_note' => { 'internal' => true } }] },
            { 'name' => 'executor', 'type' => 'AgentComponent', 'toolset' => %w[read_file grep] }
          ]
        }
      end

      it 'returns tool names, normalising hash entries and preserving multiplicity' do
        expect(extracted).to eq(%w[read_file create_merge_request_note read_file grep])
      end
    end

    context 'when a component has a single tool_name' do
      let(:definition) do
        {
          'components' => [
            { 'name' => 'tool_runner', 'type' => 'DeterministicStepComponent', 'tool_name' => 'edit_file' }
          ]
        }
      end

      it { is_expected.to eq(['edit_file']) }
    end

    context 'when a component has both toolset and tool_name' do
      let(:definition) do
        {
          'components' => [
            { 'name' => 'tool_runner', 'type' => 'DeterministicStepComponent',
              'toolset' => %w[read_file grep], 'tool_name' => 'edit_file' }
          ]
        }
      end

      it 'collects tools from both toolset and tool_name' do
        expect(extracted).to eq(%w[read_file grep edit_file])
      end
    end

    context 'when a component has neither toolset nor tool_name' do
      let(:definition) do
        {
          'components' => [
            { 'name' => 'human_input', 'type' => 'HumanInputComponent' }
          ]
        }
      end

      it { is_expected.to eq([]) }
    end

    context 'with a mix of component shapes' do
      let(:definition) do
        {
          'components' => [
            { 'name' => 'planner', 'type' => 'AgentComponent', 'toolset' => %w[edit_file read_file] },
            { 'name' => 'tool_runner', 'type' => 'DeterministicStepComponent', 'tool_name' => 'edit_file' },
            { 'name' => 'human_input', 'type' => 'HumanInputComponent' }
          ]
        }
      end

      it 'collects tools from each component without deduplicating' do
        expect(extracted).to eq(%w[edit_file read_file edit_file])
      end
    end
  end
end
