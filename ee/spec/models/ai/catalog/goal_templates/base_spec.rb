# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Base, feature_category: :duo_agent_platform do
  describe '.resolve' do
    it 'raises NotImplementedError' do
      expect do
        described_class.resolve(event_type: :mention, resource: nil, user_input: 'test')
      end.to raise_error(NotImplementedError, /must implement .resolve/)
    end
  end

  describe '.default_mention_goal' do
    let(:user_input) { '@duo Please help me with this task' }

    context 'when resource has an iid' do
      let_it_be(:project) { create(:project) }
      let_it_be(:issue) { create(:issue, project: project) }

      it 'returns the documented mention goal format using iid' do
        result = described_class.default_mention_goal(resource: issue, user_input: user_input)
        expect(result).to eq("Input: #{user_input}\nContext: {Issue IID: #{issue.iid}}")
      end

      it 'uses the demodulized class name as resource_type' do
        result = described_class.default_mention_goal(resource: issue, user_input: user_input)
        expect(result).to include('Issue IID:')
      end
    end

    context 'when resource does not have an iid' do
      let_it_be(:project) { create(:project) }

      it 'falls back to the resource id and uses ID as the id type' do
        result = described_class.default_mention_goal(resource: project, user_input: user_input)
        expect(result).to eq("Input: #{user_input}\nContext: {Project ID: #{project.id}}")
      end
    end

    context 'when user_input contains format string sequences' do
      let(:malicious_input) { 'Fix %{resource_type} and %{unknown_key} please' }
      let_it_be(:project) { create(:project) }
      let_it_be(:issue) { create(:issue, project: project) }

      it 'preserves literal %{...} sequences in user input without raising' do
        result = described_class.default_mention_goal(resource: issue, user_input: malicious_input)
        expect(result).to include('%{unknown_key}')
        expect(result).to include('Fix %{resource_type}')
      end
    end
  end

  describe '.interpolate' do
    let(:template) { 'Hello %{name}, you are working on %{resource_url}' }

    it 'substitutes vars into the template' do
      result = described_class.interpolate(template, vars: { name: 'Alice', resource_url: 'https://example.com' })
      expect(result).to eq('Hello Alice, you are working on https://example.com')
    end

    it 'substitutes user_input last' do
      template_with_input = '%{resource_url}: %{user_input}'
      result = described_class.interpolate(
        template_with_input,
        vars: { resource_url: 'https://example.com' },
        user_input: 'Fix %{resource_url} please'
      )

      # user_input should be inserted literally, not re-interpreted
      expect(result).to eq('https://example.com: Fix %{resource_url} please')
    end

    it 'returns the template without user_input substitution when user_input is nil' do
      template_with_input = '%{name}: %{user_input}'
      result = described_class.interpolate(template_with_input, vars: { name: 'Alice' })
      expect(result).to eq('Alice: %{user_input}')
    end
  end
end
