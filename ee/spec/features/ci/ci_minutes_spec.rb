# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Compute minutes', :js, time_travel_to: '2022-06-05', feature_category: :continuous_integration do
  include UsageQuotasHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, name: 'Project 1', namespace: user.namespace) }

  def create_ci_minutes_usage(minutes, date)
    create(:ci_namespace_monthly_usage, namespace: user.namespace, amount_used: minutes, date: date)
    create(:ci_project_monthly_usage, project: project, amount_used: minutes, date: date)
  end

  before do
    create_ci_minutes_usage(50, Date.new(Time.zone.now.year, 5, 1))
    create_ci_minutes_usage(60, Date.new(Time.zone.now.year, 6, 1))

    setup_usage_quotas_env(user.namespace.id)
    sign_in(user)

    visit profile_usage_quotas_path
  end

  it 'renders a year dropdown and a months dropdown of available analytics for project charts' do
    wait_for_requests

    expect(page.all('[data-testid="minutes-usage-year-dropdown"]').size).to eq 1

    find_by_testid('minutes-usage-year-dropdown').click

    within_testid('minutes-usage-year-dropdown') do
      expect(page.all('.gl-new-dropdown-item').size).to eq 1
    end

    find_by_testid('minutes-usage-month-dropdown').click

    within_testid('minutes-usage-month-dropdown') do
      expect(page.all('.gl-new-dropdown-item').size).to eq 12
    end
  end
end
