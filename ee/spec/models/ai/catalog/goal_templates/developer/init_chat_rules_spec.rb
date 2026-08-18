# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer::InitChatRules, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }

  describe '.vars' do
    it 'returns project full_path, default_branch and triggered_by_username', :aggregate_failures do
      vars = described_class.vars(resource: project, params: { triggered_by_username: 'alice' })

      expect(vars[:project_full_path]).to eq(project.full_path)
      expect(vars[:default_branch]).to eq(project.default_branch_or_main)
      expect(vars[:triggered_by_username]).to eq('alice')
    end
  end

  describe '.template' do
    it 'stays within the workflow goal size limit' do
      expect(described_class.template.bytesize).to be < 16.kilobytes
    end

    it 'names the target file' do
      expect(described_class.template).to include('.gitlab/duo/chat-rules.md')
    end

    it 'distinguishes chat-rules from AGENTS.md and notes the Code Review Flow exclusion',
      :aggregate_failures do
      template = described_class.template

      expect(template).to include('AGENTS.md')
      expect(template).to include('Code Review Flow')
    end

    it 'instructs the agent to open a draft merge request' do
      expect(described_class.template).to include('draft merge request')
    end
  end
end
