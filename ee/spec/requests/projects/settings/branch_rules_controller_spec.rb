# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects::Settings::BranchRules', feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    sign_in(user)
  end

  describe 'GET /projects/:id/settings/branch_rules' do
    it 'pushes licensed features' do
      expect_next_instance_of(Projects::Settings::BranchRulesController) do |controller|
        expect(controller).to receive(:push_licensed_feature).with(:branch_rule_squash_options, project)
      end

      get project_settings_repository_branch_rules_path(project)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
