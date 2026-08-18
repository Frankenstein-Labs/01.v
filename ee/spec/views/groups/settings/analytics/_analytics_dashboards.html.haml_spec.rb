# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/analytics/_analytics_dashboards.html.haml', feature_category: :value_stream_management do
  let_it_be(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
  end

  it 'renders a help link' do
    render

    expect(rendered).to have_link('What is Analytics Dashboards?',
      href: help_page_path('user/analytics/value_streams_dashboard.md'))
  end

  it 'renders a link to the group analytics dashboards' do
    render

    expect(rendered).to have_link('Analytics Dashboards', href: group_analytics_dashboards_path(group))
  end

  it 'renders the vue project select app' do
    render

    expect(rendered).to have_selector('.js-vue-project-select')
    expect(rendered).to have_selector("[data-group-id='#{group.id}']")
  end
end
