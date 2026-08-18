# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::Postgresql::CodeSuggestionUsageService, feature_category: :value_stream_management do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:user) { create(:user) }

  let_it_be(:counts) do
    # Create events within the date range
    create(:ai_events_count,
      namespace: namespace,
      user: user,
      event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
      events_date: 15.days.ago.to_date,
      total_occurrences: 25
    )

    create(:ai_events_count,
      namespace: namespace,
      user: user,
      event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
      events_date: 5.days.ago.to_date,
      total_occurrences: 30
    )

    create(:ai_events_count,
      namespace: namespace,
      user: user,
      event: Ai::EventsCount.events[:code_suggestion_accepted_in_ide],
      events_date: 10.days.ago.to_date,
      total_occurrences: 15
    )

    # not included - outside of date range
    create(:ai_events_count,
      namespace: namespace,
      user: user,
      event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
      events_date: 60.days.ago.to_date,
      total_occurrences: 100
    )

    # not included - different namespace
    create(:ai_events_count,
      namespace: create(:namespace),
      user: user,
      event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
      events_date: 5.days.ago.to_date,
      total_occurrences: 50
    )
  end

  let(:from) { 30.days.ago.to_date }
  let(:to) { Date.current }
  let(:fields) { nil }

  subject(:service) { described_class.new(namespace: namespace, from: from, to: to, fields: fields) }

  describe '#execute' do
    let(:fields) { [:shown_count, :accepted_count] }

    it 'returns success with aggregated counts for requested fields' do
      result = service.execute

      expect(result).to be_success
      expect(result.payload[:shown_count]).to eq(55) # 25 + 30
      expect(result.payload[:accepted_count]).to eq(15)
    end

    context 'when only shown_count is requested' do
      let(:fields) { [:shown_count] }

      it 'returns only shown_count' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to eq({ shown_count: 55 })
      end
    end

    context 'when only accepted_count is requested' do
      let(:fields) { [:accepted_count] }

      it 'returns only accepted_count' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to eq({ accepted_count: 15 })
      end
    end

    context 'when date range filters events correctly' do
      let(:fields) { [:shown_count] }
      let(:from) { 16.days.ago.to_date }
      let(:to) { 10.days.ago.to_date }

      it 'only counts events within the date range' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:shown_count]).to eq(25)
      end
    end
  end
end
