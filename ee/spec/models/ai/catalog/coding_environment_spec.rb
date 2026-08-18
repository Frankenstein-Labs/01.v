# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::CodingEnvironment, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  describe '.resolve' do
    subject(:resolved) do
      described_class.resolve(workflow_definition: workflow_definition, flow_config: flow_config)
    end

    let(:workflow_definition) { nil }
    let(:flow_config) { nil }

    describe 'value mapping' do
      # Matches no foundational flow, isolating the flow_config source.
      let(:workflow_definition) { 'ai_catalog_agent' }

      where(:flow_config, :expected) do
        { 'coding_environment' => 'none' }        | :none
        { 'coding_environment' => 'full' }        | :full
        { coding_environment: 'none' }            | :none
        { 'coding_environment' => 'lightweight' } | :full
        { 'coding_environment' => nil }           | :full
        'coding_environment: none'                | :full
        nil                                       | :full
      end

      with_them do
        it { is_expected.to eq(expected) }
      end
    end

    describe 'foundational flow lookup' do
      where(:workflow_definition, :expected) do
        'code_review/v1'  | :full
        'Code Review'     | :full
        'no_such_flow/v9' | :full
        nil               | :full
      end

      with_them do
        it { is_expected.to eq(expected) }
      end
    end

    describe 'precedence between the two sources' do
      let(:workflow_definition) { 'api_only/v1' }

      before do
        allow(::Ai::Catalog::FoundationalFlow).to receive(:find_by_reference)
          .with('api_only/v1')
          .and_return(instance_double(::Ai::Catalog::FoundationalFlow, coding_environment: 'none'))
      end

      context 'when there is no flow_config' do
        it { is_expected.to eq(:none) }
      end

      # Fall-through keys on a missing value, not on a missing Hash, so a flow_config
      # that declares nothing cannot mask the flow's own declaration.
      context 'when flow_config declares nothing' do
        where(:flow_config) { [[{}], [{ 'version' => 'v1' }]] }

        with_them do
          it { is_expected.to eq(:none) }
        end
      end

      context 'when flow_config declares a value' do
        let(:flow_config) { { 'coding_environment' => 'full' } }

        it 'takes precedence over the foundational flow' do
          expect(resolved).to eq(:full)
        end
      end
    end

    # FoundationalFlow.[] back-fills agent_privileges on the process-wide registry
    # instance. Reading coding_environment must not trigger that write.
    it 'does not use the mutating FoundationalFlow.[] lookup' do
      expect(::Ai::Catalog::FoundationalFlow).not_to receive(:[])

      described_class.resolve(workflow_definition: 'code_review/v1')
    end
  end
end
