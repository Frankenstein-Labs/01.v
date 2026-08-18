# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer::InitCodeowners, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :small_repo) }

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

    it 'targets the CODEOWNERS file' do
      expect(described_class.template).to include('CODEOWNERS')
    end

    it 'covers the LLM-injection surface', :aggregate_failures do
      template = described_class.template

      expect(template).to include('AGENTS.md')
      expect(template).to include('**/AGENTS.md')
      expect(template).to include('.gitlab/duo/')
      expect(template).to include('skills/')
    end

    it 'requires @user/@group/team owners and forbids a wildcard fallback by default', :aggregate_failures do
      template = described_class.template

      expect(template).to include('@user')
      expect(template).to include('@group/team')
      expect(template).to include('* @owner')
    end

    it 'resolves a real owner and excludes bot/service accounts', :aggregate_failures do
      template = described_class.template

      expect(template).to include('real, existing')
      expect(template).to include('Maintainer')
      expect(template).to match(/service account/i)
    end

    it 'uses the injected triggering username instead of fetching the current user', :aggregate_failures do
      template = described_class.template

      expect(template).to include('%{triggered_by_username}')
      expect(template).not_to include('current user')
    end

    it 'instructs the agent to open a draft merge request' do
      expect(described_class.template).to include('draft merge request')
    end
  end
end
