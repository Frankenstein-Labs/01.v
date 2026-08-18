# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::AiUsage::UsageEventsResolver, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:user) { create(:user, namespace: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let(:subgroup) { create(:group, parent: group) }

  let_it_be(:params) do
    {
      start_date: 20.days.ago.to_date,
      end_date: 1.day.from_now.to_date
    }
  end

  let_it_be(:usage_event) { create(:ai_usage_event, user: user, namespace: group, timestamp: 2.days.ago) }
  let_it_be(:usage_event2) { create(:ai_usage_event, user: user, namespace: group, timestamp: 1.day.ago) }
  let_it_be(:old_usage_event) do
    create(:ai_usage_event, user: user, namespace: group, timestamp: params[:start_date] - 1.day)
  end

  let_it_be(:future_usage_event) do
    create(:ai_usage_event, user: user, namespace: group, timestamp: params[:end_date] + 1.day)
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

    it 'returns all events in given timeframe' do
      expect(resolver.to_a).to eq([usage_event2, usage_event])
    end

    it 'supports unexpected enums and returns the event with an empty event type' do
      unknown_event = create(:ai_usage_event, :with_unknown_event, user: user, namespace: group, timestamp: 1.day.ago)

      result = resolver
      expect(result).to eq([unknown_event, usage_event2, usage_event])
      expect(result.first.event).to be_nil
    end
  end
end
