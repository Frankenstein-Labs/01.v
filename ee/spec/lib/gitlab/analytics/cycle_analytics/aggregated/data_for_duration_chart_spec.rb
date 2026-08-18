# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::Aggregated::DataForDurationChart do
  let_it_be(:stage) { create(:cycle_analytics_stage, start_event_identifier: :issue_created, end_event_identifier: :issue_closed) }
  let_it_be(:project) { create(:project, group: stage.namespace) }
  let_it_be(:issue_1) { create(:issue, project: project) }
  let_it_be(:issue_2) { create(:issue, project: project) }
  let_it_be(:issue_3) { create(:issue, project: project) }

  subject(:result) do
    described_class
      .new(stage: stage, params: {}, query: Analytics::CycleAnalytics::IssueStageEvent.all)
      .average_by_day
  end

  describe 'calculating the daily average stage duration', :aggregate_failures do
    let_it_be(:end_timestamp_1) { Time.zone.local(2020, 5, 6, 12, 0) }
    let_it_be(:end_timestamp_2) { Time.zone.local(2020, 5, 15, 10, 0) }

    # 1 day in milliseconds = 86_400_000

    let_it_be(:event_1) do
      # 3 days between start and end events
      create(:cycle_analytics_issue_stage_event, issue_id: issue_1.id,
        start_event_timestamp: end_timestamp_1 - 3.days,
        end_event_timestamp: end_timestamp_1, duration_in_milliseconds: 100_000_000)
    end

    let_it_be(:event_2) do
      # 3 days between start and end events
      create(:cycle_analytics_issue_stage_event, issue_id: issue_2.id,
        start_event_timestamp: end_timestamp_2 - 3.days,
        end_event_timestamp: end_timestamp_2, duration_in_milliseconds: 50_000_000
      )
    end

    let_it_be(:event3) do
      # 1 day between start and end events
      create(:cycle_analytics_issue_stage_event, issue_id: issue_3.id,
        start_event_timestamp: end_timestamp_2 - 1.day,
        end_event_timestamp: end_timestamp_2, duration_in_milliseconds: 10_000
      )
    end

    it 'calculates duration from database column duration_in_milliseconds' do
      average_two_days_ago = result[0]
      average_today = result[1]

      expect(average_two_days_ago).to have_attributes(date: end_timestamp_1.to_date, average_duration_in_seconds: 100000)
      expect(average_today).to have_attributes(date: end_timestamp_2.to_date, average_duration_in_seconds: 25005)
    end
  end
end
