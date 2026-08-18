# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group CI/CD Analytics', :js, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }

  let_it_be(:project_1, freeze: false) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:project_3, freeze: false) { create(:project, group: subgroup) }
  let_it_be(:unrelated_project, freeze: false) { create(:project) }

  let_it_be(:releases_1) { create_list(:release, 3, project: project_1) }
  let_it_be(:releases_3, freeze: false) { create_list(:release, 2, project: project_3) }
  let_it_be(:unrelated_release) { create(:release, project: unrelated_project) }

  before do
    stub_licensed_features(group_ci_cd_analytics_releases: true, group_ci_cd_analytics_pipelines: false)
    group.add_reporter(user)
    sign_in(user)
    visit group_analytics_ci_cd_analytics_path(group)
  end

  it 'renders statistics about release within the group', :aggregate_failures do
    click_on 'Release statistics'

    within_testid('release-stats-card') do
      expect(page).to have_content 'Releases All time'

      expect(page).to have_content '5 Releases 67% Projects with releases'
    end
  end
end
