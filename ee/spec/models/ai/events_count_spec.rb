# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::EventsCount, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_in_subgroup) { create(:project, namespace: subgroup) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:from_date) { 2.weeks.ago.to_date }
  let_it_be(:to_date) { Date.current }
  let_it_be(:outside_date) { 1.month.ago.to_date }

  let_it_be(:event_1) do
    create(:ai_events_count,
      namespace: project.project_namespace,
      event: :code_suggestion_accepted_in_ide,
      events_date: from_date,
      total_occurrences: 10)
  end

  let_it_be(:event_2) do
    create(:ai_events_count,
      namespace: project.project_namespace,
      event: :code_suggestion_accepted_in_ide,
      events_date: from_date + 3.days,
      total_occurrences: 25)
  end

  let_it_be(:event_3) do
    create(:ai_events_count,
      namespace: project_in_subgroup.project_namespace,
      event: :code_suggestion_shown_in_ide,
      events_date: to_date,
      total_occurrences: 15)
  end

  let_it_be(:event_4) do
    create(:ai_events_count,
      namespace: other_project.project_namespace,
      event: :code_suggestion_shown_in_ide,
      events_date: from_date,
      total_occurrences: 30)
  end

  let_it_be(:event_5) do
    create(:ai_events_count,
      namespace: project.project_namespace,
      event: :code_suggestion_shown_in_ide,
      events_date: outside_date,
      total_occurrences: 50)
  end

  it { is_expected.to validate_presence_of(:organization_id) }
  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to validate_presence_of(:events_date) }
  it { is_expected.to validate_presence_of(:event) }
  it { is_expected.to validate_presence_of(:total_occurrences) }
  it { is_expected.to validate_numericality_of(:total_occurrences).is_greater_than_or_equal_to(0) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:namespace).optional }

  it 'uses id as the primary key' do
    expect(described_class.primary_key).to eq('id')
  end

  it 'has 3 months data retention' do
    expect(described_class.partitioning_strategy.retain_for).to eq(3.months)
  end

  describe 'enum event' do
    it 'defines event enum based on AI::UsageEvent events' do
      expect(described_class.events).to eq(Ai::UsageEvent.events)
    end
  end

  describe 'scopes' do
    describe '.for_namespace' do
      context 'when namespace is a Project' do
        it 'returns events for the specific project' do
          results = described_class.for_namespace(project.project_namespace)

          expect(results).to contain_exactly(event_1, event_2, event_5)
        end
      end

      context 'when namespace is a Group' do
        it 'returns events for all projects within the group hierarchy' do
          results = described_class.for_namespace(group)

          expect(results).to contain_exactly(event_1, event_2, event_3, event_5)
        end
      end
    end

    describe '.for_event' do
      it 'returns events matching the specified event type' do
        results = described_class.for_event(:code_suggestion_shown_in_ide)

        expect(results).to contain_exactly(event_3, event_4, event_5)
      end
    end

    describe '.in_date_range' do
      it 'returns events within the date range' do
        results = described_class.in_date_range(from_date, to_date)

        expect(results).to contain_exactly(event_1, event_2, event_3, event_4)
      end
    end

    describe '.total_occurrences_for' do
      it 'sums total occurrences for a given namespace' do
        total = described_class.total_occurrences_for(
          namespace: group,
          event: :code_suggestion_accepted_in_ide,
          from: from_date,
          to: to_date
        )

        # event_1 (10) + event_2 (25)
        expect(total).to eq(35)
      end
    end
  end
end
