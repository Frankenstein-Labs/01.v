# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer::InitExecutionEnv, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :small_repo) }

  describe '.vars' do
    it 'returns project full_path and default_branch', :aggregate_failures do
      vars = described_class.vars(resource: project, params: {})

      expect(vars[:project_full_path]).to eq(project.full_path)
      expect(vars[:default_branch]).to eq(project.default_branch_or_main)
    end
  end

  describe '.template' do
    it 'stays within the workflow goal size limit' do
      expect(described_class.template.bytesize).to be < 16.kilobytes
    end

    it 'names the target file' do
      expect(described_class.template).to include('.gitlab/duo/agent-config.yml')
    end

    it 'lists the four schema keys the agent must produce', :aggregate_failures do
      template = described_class.template

      expect(template).to include('image')
      expect(template).to include('setup_script')
      expect(template).to include('cache')
      expect(template).to include('network_policy')
    end

    it 'instructs the agent to open a draft merge request' do
      expect(described_class.template).to include('draft merge request')
    end
  end
end
