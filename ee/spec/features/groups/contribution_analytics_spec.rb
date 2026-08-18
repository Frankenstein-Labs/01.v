# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Contribution Analytics', :js, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:empty_project) { create(:project, namespace: group) }

  def visit_contribution_analytics
    visit group_path(group)

    within_testid('super-sidebar') do
      click_button 'Analyze'
      click_link 'Contribution analytics'
    end
  end

  before_all do
    group.add_owner(user)
  end

  before do
    sign_in(user)
    stub_feature_flags(contributions_analytics_dashboard: false)
  end

  describe 'visit Contribution Analytics page for group' do
    before do
      visit_contribution_analytics
    end

    it 'displays Contribution Analytics' do
      expect(page).to have_content "Contribution analytics for issues, merge requests and push"
    end

    it 'displays text indicating no pushes, merge requests and issues' do
      expect(page).to have_content "No pushes for the selected time period."
      expect(page).to have_content "No merge requests for the selected time period."
      expect(page).to have_content "No issues for the selected time period."
    end
  end

  describe 'Contribution Analytics Tabs' do
    before do
      visit group_contribution_analytics_path(group)
    end

    it 'displays the Date Range GlTabs' do
      within_testid('contribution-analytics-date-nav') do
        expect(page).to have_link 'Last week',
          href: group_contribution_analytics_path(group, start_date: 1.week.ago.to_date)
        expect(page).to have_link 'Last month',
          href: group_contribution_analytics_path(group, start_date: 1.month.ago.to_date)
        expect(page).to have_link 'Last 3 months',
          href: group_contribution_analytics_path(group, start_date: 3.months.ago.to_date)
      end
    end

    it 'defaults active to Last Week' do
      within_testid('contribution-analytics-date-nav') do
        expect(page.find('.active')).to have_text('Last week')
      end
    end

    it 'clicking a different option updates correctly' do
      within_testid('contribution-analytics-date-nav') do
        page.find_link('Last 3 months').click
      end

      wait_for_requests

      within_testid('contribution-analytics-date-nav') do
        expect(page.find('.active')).to have_text('Last 3 months')
      end
    end
  end

  describe('Contribution Analytics data source') do
    let(:using_clickhouse_badge) { find_by_testid('using-clickhouse-badge') }

    context 'when ClickHouse is the data source' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
        visit_contribution_analytics
      end

      it 'displays `Using ClickHouse` badge' do
        within_testid('contribution-analytics-header') do
          expect(using_clickhouse_badge).to have_text('Using ClickHouse')
        end
      end

      it 'displays popover upon hovering over `Using ClickHouse` badge',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/446043' do
        using_clickhouse_badge.hover

        page.within('.gl-popover') do
          expect(page).to have_content(
            'This page sources data from the analytical database ClickHouse, ' \
            'with a few minutes of delay.'
          )
        end
      end
    end

    context 'when ClickHouse is not the data source' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        visit_contribution_analytics
      end

      it 'does not display `Using ClickHouse` badge' do
        within_testid('contribution-analytics-header') do
          expect(page).not_to have_content('Using ClickHouse')
        end
      end
    end
  end

  describe 'Analytics charts date range filtering' do
    let_it_be(:project) { create(:project, :repository, namespace: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:merge_request) { create(:merge_request, :simple, source_project: project) }
    let_it_be(:push_data) { Gitlab::DataBuilder::Push.build_sample(project, user) }

    def create_contribution_event(author, target, action, created_at: Time.current)
      Event.create!(
        project: project,
        action: action,
        target: target,
        author: author,
        created_at: created_at
      )
    end

    def create_push_contribution(author, created_at: Time.current)
      event = create_contribution_event(author, nil, :pushed, created_at: created_at)
      PushEventPayloadService.new(event, push_data).execute
    end

    context 'when events exist within the default date range' do
      before do
        create_push_contribution(user)
        create_contribution_event(user, issue, :closed)
        create_contribution_event(user, merge_request, :created)

        visit group_contribution_analytics_path(group)
        wait_for_all_requests
      end

      it 'displays contribution data in all charts', :aggregate_failures do
        within_testid('push-content') do
          expect(page).to have_content('1 push')
          expect(page).to have_content('1 contributor')
        end

        within_testid('merge-request-content') do
          expect(page).to have_content('1 created')
        end

        within_testid('issue-content') do
          expect(page).to have_content('1 closed')
        end
      end
    end

    context 'when events exist only outside the default date range' do
      let_it_be(:other_user) { create(:user) }

      before_all do
        group.add_developer(other_user)
      end

      before do
        create_push_contribution(user, created_at: 2.weeks.ago)
        create_contribution_event(user, issue, :closed, created_at: 2.weeks.ago)
        create_contribution_event(user, merge_request, :created, created_at: 2.weeks.ago)

        create_push_contribution(other_user, created_at: 3.months.ago)
        create_contribution_event(other_user, issue, :closed, created_at: 3.months.ago)
        create_contribution_event(other_user, merge_request, :created, created_at: 3.months.ago)
      end

      it 'shows empty charts with the default date range', :aggregate_failures do
        visit group_contribution_analytics_path(group)
        wait_for_all_requests

        expect(page).to have_content('No pushes for the selected time period.')
        expect(page).to have_content('No merge requests for the selected time period.')
        expect(page).to have_content('No issues for the selected time period.')
      end

      it 'displays chart data when start_date includes the events', :aggregate_failures do
        visit group_contribution_analytics_path(group, start_date: 1.month.ago.to_date)
        wait_for_all_requests

        within_testid('push-content') do
          expect(page).to have_content('1 push')
          expect(page).to have_content('1 contributor')
        end

        within_testid('merge-request-content') do
          expect(page).to have_content('1 created')
        end

        within_testid('issue-content') do
          expect(page).to have_content('1 closed')
        end
      end

      it 'displays chart data after selecting a broader date range tab', :aggregate_failures do
        visit group_contribution_analytics_path(group)
        wait_for_all_requests

        within_testid('contribution-analytics-date-nav') do
          click_link 'Last month'
        end

        wait_for_all_requests

        within_testid('push-content') do
          expect(page).to have_content('1 push')
          expect(page).to have_content('1 contributor')
        end

        within_testid('merge-request-content') do
          expect(page).to have_content('1 created')
        end

        within_testid('issue-content') do
          expect(page).to have_content('1 closed')
        end
      end
    end
  end

  context 'when contribution_analytics_dashboard feature flag is enabled' do
    before do
      stub_licensed_features(group_level_analytics_dashboard: true)
      stub_feature_flags(contributions_analytics_dashboard: true)
      visit group_contribution_analytics_path(group)

      wait_for_all_requests
    end

    it 'redirects to the new dashboard page', :aggregate_failures do
      expect(page).to have_current_path(group_analytics_dashboards_path(group, vueroute: 'contributions_dashboard'),
        ignore_query: true)
      expect(page).to have_content _('Contributions Dashboard')
    end
  end
end
