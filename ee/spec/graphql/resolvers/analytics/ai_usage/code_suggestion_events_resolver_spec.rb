# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::AiUsage::CodeSuggestionEventsResolver, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:user) { create(:user, namespace: group) }
  let_it_be(:user2) { create(:user, namespace: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:another_project) { create(:project) }

  let_it_be(:params) do
    {
      start_date: 20.days.ago.to_date,
      end_date: 1.day.from_now.to_date
    }
  end

  let_it_be(:usage_event) do
    create(:ai_usage_event, event: 'code_suggestion_shown_in_ide', user: user, namespace: group, timestamp: 2.days.ago)
  end

  let_it_be(:usage_event2) do
    create(:ai_usage_event, event: 'code_suggestion_accepted_in_ide', user: user, namespace: group,
      timestamp: 1.day.ago)
  end

  let_it_be(:usage_event3) do
    create(:ai_usage_event, event: 'code_suggestion_rejected_in_ide', user: user, namespace: group,
      timestamp: 1.day.ago)
  end

  let_it_be(:unrelated_usage_event) do
    create(:ai_usage_event, event: 'troubleshoot_job', user: user, namespace: group, timestamp: 1.day.ago)
  end

  let_it_be(:old_usage_event) do
    create(:ai_usage_event, event: 'code_suggestion_shown_in_ide', user: user, namespace: group,
      timestamp: params[:start_date] - 1.day)
  end

  let_it_be(:future_usage_event) do
    create(:ai_usage_event, event: 'code_suggestion_shown_in_ide', user: user, namespace: group,
      timestamp: params[:end_date] + 1.day)
  end

  let_it_be(:different_user_usage_event) do
    create(:ai_usage_event, event: 'code_suggestion_shown_in_ide', user: user2, namespace: group,
      timestamp: 1.day.ago)
  end

  let_it_be(:contribution_event) do
    create(:event, :pushed, project: project, author: user, target: nil, created_at: 1.day.ago)
  end

  subject(:resolver) { resolve(described_class, obj: group, args: params, ctx: { current_user: user }) }

  describe '#ready', :freeze_time do
    it 'raises an error when timeframe is too large' do
      expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
        "maximum date range is 1 month") do
        resolve(described_class, obj: group,
          args: { start_date: 40.days.ago.to_date, end_date: 1.day.ago.to_date },
          ctx: { current_user: user })
      end
    end
  end

  describe '#resolve', :freeze_time do
    subject(:resolver) { resolve(described_class, obj: group, args: params, ctx: { current_user: user }).to_a }

    it 'returns all related events in given timeframe' do
      expect(resolver.to_a).to eq([different_user_usage_event, usage_event3, usage_event2, usage_event])
    end
  end
end
