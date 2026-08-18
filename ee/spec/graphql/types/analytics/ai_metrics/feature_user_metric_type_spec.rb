# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::FeatureUserMetricType, feature_category: :value_stream_management do
  include GraphqlHelpers

  let(:current_user) { nil }

  describe '.[]' do
    it 'generates a GraphQL type for a given feature' do
      type = described_class[:code_suggestions]

      expect(type).to be < Types::BaseObject
      expect(type.graphql_name).to eq('codeSuggestionsUserMetrics')
      expect(type.description).to eq(
        'Code Suggestions user metrics for a user. ' \
          'Requires ClickHouse. Premium and Ultimate with GitLab Duo Enterprise only.'
      )
    end

    it 'generates different types for different features' do
      code_suggestions_type = described_class[:code_suggestions]
      chat_type = described_class[:chat]

      expect(code_suggestions_type).not_to eq(chat_type)
      expect(code_suggestions_type.graphql_name).to eq('codeSuggestionsUserMetrics')
      expect(chat_type.graphql_name).to eq('chatUserMetrics')
    end

    it 'includes Analytics::AiEventFields' do
      type = described_class[:code_review]

      expect(type.included_modules).to include(Analytics::AiEventFields)
    end

    it 'includes totalEventCount field' do
      type = described_class[:code_suggestions]

      expect(type.fields).to include('totalEventCount')
      expect(type.fields['totalEventCount'].type.unwrap).to eq(GraphQL::Types::Int)
      expect(type.fields['totalEventCount'].description).to eq(
        'Total count of all Code Suggestions events for the user.'
      )
    end

    it 'generates event count fields for the feature' do
      type = described_class[:code_suggestions]

      expect(type.fields).to include('codeSuggestionShownInIdeEventCount')
      expect(type.fields).to include('codeSuggestionAcceptedInIdeEventCount')
      expect(type.fields).to include('codeSuggestionRejectedInIdeEventCount')
    end

    it 'includes lastDuoActivityOn field' do
      type = described_class[:code_suggestions]

      expect(type.fields).to include('lastDuoActivityOn')
      expect(type.fields['lastDuoActivityOn'].type.unwrap).to eq(Types::DateType)
      expect(type.fields['lastDuoActivityOn'].description).to eq(
        'Date of the last Code Suggestions activity for the user.'
      )
    end
  end
end
