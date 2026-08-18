# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::PostgresqlUsageEventsFinder, feature_category: :value_stream_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user, freeze: false) { create(:user, namespace: group) }

  let_it_be(:to) { Time.zone.today }
  let_it_be(:from) { Time.zone.today - 20.days }

  let(:finder_params) do
    { from: from, to: to, namespace: group }
  end

  subject(:finder) { described_class.new(user, **finder_params).execute }

  describe '#execute' do
    context 'when there are no events' do
      it 'returns an empty relation' do
        expect(finder).to be_empty
      end
    end

    context 'when there are events' do
      let_it_be(:event1) do
        create(:ai_usage_event, user: user, namespace: group,
          timestamp: 2.days.ago, event: 'code_suggestion_shown_in_ide')
      end

      let_it_be(:event2) do
        create(:ai_usage_event, user: user, namespace: group,
          timestamp: 1.day.ago, event: 'code_suggestion_accepted_in_ide')
      end

      let_it_be(:event_before_timeframe) do
        create(:ai_usage_event, user: user, namespace: group, timestamp: from - 1.day)
      end

      let_it_be(:event_after_timeframe) do
        create(:ai_usage_event, user: user, namespace: group, timestamp: to + 1.day)
      end

      context 'without additional filters' do
        it 'returns usage events matching provided timeframe ordered by timestamp desc' do
          expect(finder).to match_array([event2, event1])
        end
      end

      context 'with namespace filter' do
        let(:finder_params) do
          super().merge(namespace: group)
        end

        it 'includes only events from namespace hierarchy' do
          child_event = create(:ai_usage_event, user: user, namespace: subgroup, timestamp: to)
          _other_namespace_event = create(:ai_usage_event, user: user, namespace: create(:group), timestamp: to)

          expect(finder).to contain_exactly(event1, event2, child_event)
        end
      end

      context 'with event names filter' do
        let(:finder_params) do
          super().merge(events: ['code_suggestion_accepted_in_ide'])
        end

        it 'returns only events with corresponding event name' do
          expect(finder.to_a).to eq([event2])
        end

        context 'when event names filter is empty' do
          let(:finder_params) do
            super().merge(events: [])
          end

          it 'returns usage events for all users within the provided timeframe' do
            expect(finder.to_a).to match_array([event1, event2])
          end
        end
      end

      context 'with users filter' do
        let_it_be(:other_user) { create(:user) }
        let_it_be(:other_user_event) do
          create(:ai_usage_event, user: other_user, timestamp: 2.days.ago,
            event: 'code_suggestion_shown_in_ide', namespace: group)
        end

        let(:finder_params) do
          super().merge(users: [user.id])
        end

        it 'returns only events of corresponding users' do
          expect(finder.to_a).to match_array([event1, event2])
        end

        context 'when users filter is empty' do
          let(:finder_params) do
            super().merge(users: [])
          end

          it "doesn't apply any users filtering" do
            expect(finder.to_a).to match_array([other_user_event, event1, event2])
          end
        end
      end
    end

    context 'when retrieving an unrecognized enum' do
      let_it_be(:usage_event) do
        create(:ai_usage_event, :with_unknown_event, user: user, namespace: group, timestamp: to)
      end

      it 'returns an array with the event and an empty event type' do
        result = finder
        expect(result).to contain_exactly(usage_event)
        expect(result.first.event).to be_nil
      end
    end
  end
end
