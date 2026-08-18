# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maintainer manages project runners', feature_category: :fleet_visibility do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }

  before do
    sign_in(user)
  end

  context 'with a runner from another project where user is banned', :saas, :js do
    let_it_be(:other_project) { create(:project, :in_group) }
    let_it_be(:other_project_runner) { create(:ci_runner, :project, projects: [other_project]) }

    before do
      stub_licensed_features(unique_project_download_limit: true)

      create(:group_member, :banned, :maintainer, source: other_project.root_ancestor, user: user)

      visit project_runners_path(project)
    end

    it 'is not shown' do
      click_on 'Other available project runners'

      expect(page).not_to have_content(other_project_runner.short_sha)
    end
  end
end
