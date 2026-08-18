# frozen_string_literal: true

# Generic assertions for any dashboard rendered under
# `/explore/analytics_dashboards/:slug`. Callers must define `dashboard_title`
# and `panel_titles` (an Array of String panel titles).
RSpec.shared_examples 'a rendered analytics dashboard' do
  it 'renders the dashboard title' do
    expect(page).to have_content dashboard_title
  end

  it 'renders a panel for each entry in the dashboard config', :aggregate_failures do
    panel_titles.each do |title|
      expect(page).to have_content title
    end
  end

  it 'renders the dashboard filters bar with all three filters', :aggregate_failures do
    within_testid('dashboard-filters') do
      expect(page).to have_content s_('AnalyticsDashboards|Groups')
      expect(page).to have_content s_('AnalyticsDashboards|Projects')
      expect(page).to have_content s_('AnalyticsDashboards|Date range')
    end
  end
end
