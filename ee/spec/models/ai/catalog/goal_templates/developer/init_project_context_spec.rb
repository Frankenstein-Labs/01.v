# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer::InitProjectContext, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :small_repo) }

  describe '.vars' do
    it 'returns project full_path and default_branch' do
      vars = described_class.vars(resource: project, params: {})

      expect(vars[:project_full_path]).to eq(project.full_path)
      expect(vars[:default_branch]).to eq(project.default_branch_or_main)
    end
  end

  describe '.template' do
    it 'stays within the workflow goal size limit' do
      expect(described_class.template.bytesize).to be < 16.kilobytes
    end
  end
end
