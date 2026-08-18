# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Explore > Analytics dashboards > System dashboards', :js, :with_current_organization,
  feature_category: :custom_dashboards_foundation do
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(product_analytics: true)

    sign_in(user)
  end

  describe 'Merge Request analytics' do
    let_it_be(:mr_dashboard) do
      Analytics::CustomDashboards::SystemDashboardsLoader.find_by_slug('merge_requests')
    end

    let(:dashboard_title) { mr_dashboard.config['title'] }
    let(:panel_titles) { mr_dashboard.config['panels'].pluck('title') }

    before do
      visit explore_analytics_dashboards_path
      click_link mr_dashboard.name
    end

    it_behaves_like 'a rendered analytics dashboard'

    it 'routes to the dashboard by slug' do
      expect(page).to have_current_path(
        "#{explore_analytics_dashboards_path}/#{mr_dashboard.slug}",
        ignore_query: true
      )
    end

    it 'defaults the date range filter to the YAML-configured option (Last 365 days)' do
      within_testid('dashboard-filters') do
        expect(page).to have_content 'Last 365 days'
      end
    end
  end

  describe 'GitLab Duo and SDLC trends' do
    let_it_be(:duo_dashboard) do
      Analytics::CustomDashboards::SystemDashboardsLoader.find_by_slug('duo_and_sdlc_trends')
    end

    let(:dashboard_title) { duo_dashboard.config['title'] }

    let(:panel_titles) do
      duo_dashboard.config['panels'].pluck('title').grep_v(/%\{/)
    end

    before do
      visit explore_analytics_dashboards_path
      click_link duo_dashboard.name
    end

    it_behaves_like 'a rendered analytics dashboard'

    it 'routes to the dashboard by slug' do
      expect(page).to have_current_path(
        "#{explore_analytics_dashboards_path}/#{duo_dashboard.slug}",
        ignore_query: true
      )
    end

    it 'resolves every panel without an error state', :aggregate_failures do
      # With no analytics data seeded the panels settle on their empty state.
      # Waiting for that is what confirms the fetches finished, so the error
      # assertion below cannot pass simply by running before they start.
      expect(page).to have_content s_('Analytics|No results match your query or filter.')
      expect(page).to have_no_selector('[data-testid="alert-body"]')
    end
  end
end
