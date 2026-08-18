# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Ai::ToolRules::ToolPresenter, feature_category: :duo_agent_platform do
  describe '.display_name_for' do
    it 'converts snake_case tool names to human readable format' do
      expect(described_class.display_name_for('create_issue')).to eq('Create Issue')
      expect(described_class.display_name_for('run_git_command')).to eq('Run Git Command')
      expect(described_class.display_name_for('read_file')).to eq('Read File')
    end

    it 'handles acronyms correctly' do
      expect(described_class.display_name_for('ci_linter')).to eq('CI Linter')
      expect(described_class.display_name_for('ascp_create_scan')).to eq('ASCP Create Scan')
      expect(described_class.display_name_for('gitlab_graphql')).to eq('GitLab GraphQL')
      expect(described_class.display_name_for('run_glql_query')).to eq('Run GLQL Query')
      expect(described_class.display_name_for(
        'post_sast_fp_analysis_to_gitlab'
      )).to eq('Post SAST False Positive Analysis to GitLab')
    end

    it 'handles the double underscore edge case' do
      expect(described_class.display_name_for('gitlab__user_search')).to eq('GitLab User Search')
    end
  end
end
