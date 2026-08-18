# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiUsageDataType, feature_category: :value_stream_management do
  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:code_suggestion_events, :all)
  end

  it 'requires authorization' do
    expect(described_class).to require_graphql_authorizations(:read_enterprise_ai_analytics)
  end

  describe 'fields' do
    subject(:fields) { described_class.fields }

    it 'have proper types and resolvers' do
      expect(fields['codeSuggestionEvents'])
        .to have_graphql_type(Types::Analytics::AiUsage::CodeSuggestionEventType.connection_type)
      expect(fields['codeSuggestionEvents'])
        .to have_graphql_resolver(Resolvers::Analytics::AiUsage::CodeSuggestionEventsResolver)

      expect(fields['all']).to have_graphql_type(Types::Analytics::AiUsage::AiUsageEventType.connection_type)
      expect(fields['all']).to have_graphql_resolver(Resolvers::Analytics::AiUsage::UsageEventsResolver)
    end
  end
end
