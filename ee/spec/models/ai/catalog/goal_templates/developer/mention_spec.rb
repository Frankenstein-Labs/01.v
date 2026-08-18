# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer::Mention, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }

  describe '.vars' do
    it 'returns only the keys consumed by the template', :aggregate_failures do
      vars = described_class.vars(resource: issue, params: { note_id: 42, triggered_by_username: 'alice' })

      expect(vars.keys).to match_array([:resource_name, :triggered_by_username, :source_context])
      expect(vars[:resource_name]).to eq('issue')
      expect(vars[:triggered_by_username]).to eq('alice')
    end

    it 'uses source_context from params when provided' do
      custom_context = "Issue: https://example.com\nTitle: Test"
      vars = described_class.vars(
        resource: issue,
        params: { triggered_by_username: 'alice', source_context: custom_context }
      )

      expect(vars[:source_context]).to eq(custom_context)
    end

    it 'includes the note anchor in the default source_context fallback' do
      resource_url = Gitlab::UrlBuilder.build(issue)
      vars = described_class.vars(resource: issue, params: { note_id: 42, triggered_by_username: 'alice' })

      expect(vars[:source_context]).to eq("Issue: #{resource_url}#note_42")
    end

    it 'uses resource_url in the default source_context when note_id is absent' do
      resource_url = Gitlab::UrlBuilder.build(issue)
      vars = described_class.vars(resource: issue, params: { triggered_by_username: 'alice' })

      expect(vars[:source_context]).to eq("Issue: #{resource_url}")
    end
  end

  describe '.template' do
    it 'resolves with every placeholder filled and the conversation wired in', :aggregate_failures do
      goal = Ai::Catalog::GoalTemplates::Developer.resolve(
        event_type: :mention,
        resource: issue,
        user_input: 'Please look into this',
        params: { triggered_by_username: 'alice' }
      )

      expect(goal).not_to match(/%\{/)
      expect(goal).to include('Please look into this')
      expect(goal).to include('<conversation>')
      expect(goal).to include('<gitlab_context>')
    end

    it 'carries no self-post reply mechanics', :aggregate_failures do
      template = described_class.template

      expect(template).not_to include('%{delivery_instructions}')
      expect(template).not_to include('%{discussion_id}')
      expect(template).not_to include('%{note_url}')
    end
  end
end
