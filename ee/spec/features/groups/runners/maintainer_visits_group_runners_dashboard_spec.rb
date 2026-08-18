# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maintainer visits runners dashboard', feature_category: :fleet_visibility do
  let_it_be(:group_maintainer) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: group_maintainer) }

  before do
    sign_in(group_maintainer)
  end

  context 'when runner_performance_insights_for_namespace is available', :js do
    before do
      stub_licensed_features(runner_performance_insights_for_namespace: [group])
    end

    it 'shows dashboard link' do
      visit group_runners_path(group)

      expect(page).to have_link('Fleet dashboard', href: dashboard_group_runners_path(group))
    end

    it 'shows dashboard' do
      visit dashboard_group_runners_path(group)

      within_testid('breadcrumb-links') do
        expect(page).to have_link('Fleet dashboard')
      end
    end
  end
end
