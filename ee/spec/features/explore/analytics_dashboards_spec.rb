# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Explore > Analytics dashboards', :js, :with_current_organization,
  feature_category: :custom_dashboards_foundation do
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(product_analytics: true)

    sign_in(user)
  end

  context 'when the explore_analytics_dashboards feature flag is disabled' do
    before do
      stub_feature_flags(explore_analytics_dashboards: false)
      visit explore_analytics_dashboards_path
    end

    it 'renders a 404 page' do
      expect(page).to have_content _('Page not found')
    end
  end

  describe 'dashboards list' do
    context 'when the custom_dashboard_storage feature flag is disabled' do
      let_it_be(:stored_dashboard) do
        create(:dashboard, :organization_scoped,
          name: 'Stored metrics',
          organization: current_organization,
          created_by: user)
      end

      before do
        stub_feature_flags(custom_dashboard_storage: false)
        visit explore_analytics_dashboards_path
      end

      it 'renders the built-in dashboards without the stored dashboards', :aggregate_failures do
        system_dashboard = Analytics::CustomDashboards::SystemDashboardsLoader.all.first
        expect(page).to have_link(system_dashboard.name)

        expect(page).to have_no_link(stored_dashboard.name)
      end
    end

    context 'with no custom dashboards in the current organization' do
      before do
        visit explore_analytics_dashboards_path
      end

      it 'renders the page heading and description', :aggregate_failures do
        expect(page).to have_content _('Analytics dashboards')
        expect(page).to have_content(
          s_('AnalyticsDashboards|Keep your teams aligned around the metrics that matter most.')
        )
      end

      it 'renders the three dashboard scope tabs', :aggregate_failures do
        within('.gl-tabs') do
          expect(page).to have_link s_('AnalyticsDashboards|All')
          expect(page).to have_link s_('AnalyticsDashboards|Created by me')
          expect(page).to have_link s_('AnalyticsDashboards|Created by GitLab')
        end
      end

      it 'renders the default system dashboard in the list' do
        system_dashboard = Analytics::CustomDashboards::SystemDashboardsLoader.all.first

        expect(page).to have_link system_dashboard.name
      end
    end

    context 'with a custom dashboard in the current organization' do
      let_it_be(:dashboard_config) do
        {
          version: '2',
          title: 'Engineering dashboard',
          description: 'Engineering health metrics',
          panels: [
            {
              title: 'Total commits',
              visualization: {
                version: 1,
                type: 'SingleStat',
                data: { type: 'cube_analytics', query: {} },
                options: {}
              },
              gridAttributes: { width: 4, height: 2, xPos: 0, yPos: 0 }
            },
            {
              title: 'Open MRs',
              visualization: {
                version: 1,
                type: 'SingleStat',
                data: { type: 'cube_analytics', query: {} },
                options: {}
              },
              gridAttributes: { width: 4, height: 2, xPos: 4, yPos: 0 }
            }
          ]
        }
      end

      let_it_be(:dashboard) do
        create(:dashboard, :organization_scoped,
          name: 'Engineering metrics',
          organization: current_organization,
          created_by: user,
          config: dashboard_config)
      end

      before do
        visit explore_analytics_dashboards_path
      end

      it 'renders the dashboard row and hides the empty state', :aggregate_failures do
        expect(page).to have_link dashboard.name

        # Once the link is confirmed, you safely verify the empty state is gone.
        expect(page).not_to have_content(s_('AnalyticsDashboards|No dashboards found'), wait: 0)
      end

      context 'when the user selects the dashboard' do
        let(:dashboard_title) { dashboard_config[:title] }
        let(:panel_titles) { dashboard_config[:panels].pluck(:title) }

        before do
          click_link dashboard.name
        end

        it 'navigates to the dashboard detail view' do
          expect(page).to have_current_path("#{explore_analytics_dashboards_path}/#{dashboard.id}", ignore_query: true)
        end

        it 'prepends the dashboard title to the document title' do
          expect(page).to have_title "#{dashboard_title} · #{s_('Analytics|Analytics dashboards')}"
        end

        it_behaves_like 'a rendered analytics dashboard'

        context 'when the user edits the dashboard' do
          before do
            click_link _('Edit')
          end

          it 'prepends the edit and dashboard titles to the document title' do
            expect(page).to have_title(
              "#{_('Edit')} · #{dashboard_title} · #{s_('Analytics|Analytics dashboards')}"
            )
          end
        end
      end
    end
  end
end
