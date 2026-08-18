# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FoundationalChatAgentResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) { resolve(described_class, args: { reference: reference }) }

    context 'when the reference matches a foundational agent' do
      let(:reference) { 'duo_planner' }

      it 'returns the agent' do
        expect(resolved).to be_a(::Ai::FoundationalChatAgent)
        expect(resolved.reference).to eq('duo_planner')
        expect(resolved.name).to eq('Planner')
      end
    end

    context 'when the reference does not match any agent' do
      let(:reference) { 'nonexistent_agent' }

      it 'returns nil' do
        expect(resolved).to be_nil
      end
    end
  end
end
