# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::UserMetricsType, feature_category: :value_stream_management do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('AiUserMetrics') }

  describe 'fields' do
    it 'has base fields' do
      expect(described_class).to have_graphql_field(:user)
      expect(described_class).to have_graphql_field(:total_event_count)
    end
  end

  describe 'feature fields' do
    it 'creates FeatureUserMetricType for each feature' do
      Gitlab::Tracking::AiTracking.registered_features.each do |feature|
        field = described_class.fields[feature.to_s.camelize(:lower)]
        expect(field.type.unwrap.graphql_name).to eq("#{feature.to_s.camelize(:lower)}UserMetrics")
      end
    end

    it 'uses titleized feature name in description' do
      (Gitlab::Tracking::AiTracking.registered_features - [:troubleshoot_job]).each do |feature|
        field = described_class.fields[feature.to_s.camelize(:lower)]
        expect(field.description).to eq("#{feature.to_s.titleize} metrics for the user.")
      end
    end

    it 'has legacy description for troubleshootJob field', :aggregate_failures do
      field = described_class.fields['troubleshootJob']

      expect(field.description).to include('agentPlatformSessions')
      expect(field.description).to include('fix_pipeline/v1')
    end
  end

  describe 'deprecated fields' do
    it 'marks code_suggestions_accepted_count as deprecated' do
      field = described_class.fields['codeSuggestionsAcceptedCount']
      expect(field.deprecation_reason).to eq(
        'Use `codeSuggestions.codeSuggestionAcceptedInIdeEventCount` instead. Deprecated in GitLab 18.7.'
      )
    end

    it 'marks duo_chat_interactions_count as deprecated' do
      field = described_class.fields['duoChatInteractionsCount']
      expect(field.deprecation_reason).to eq(
        'Use `chat.requestDuoChatResponseEventCount` instead. Deprecated in GitLab 18.7.'
      )
    end

    it 'marks troubleshoot_job as deprecated' do
      field = described_class.fields['troubleshootJob']
      expect(field.deprecation_reason).to eq(
        "Legacy troubleshoot job metrics for the user (event ID 7 only). " \
          "For current GitLab Duo Agent Platform-based troubleshoot jobs, use `agentPlatformSessions` " \
          "with `flow_type = 'fix_pipeline/v1'`. Deprecated in GitLab 19.1."
      )
    end
  end

  describe '#total_event_count' do
    let_it_be(:user) { create(:user) }
    let(:object) { { 'user_id' => user.id } }
    let(:query_double) { double('clickhouse_query') } # rubocop:disable RSpec/VerifiedDoubles -- ClickHouse query builder
    let(:clickhouse_rows) do
      [{ 'user_id' => user.id, 'total_events_count' => 25 }]
    end

    let(:context) do
      {
        current_user: user,
        ai_metrics_params: {}
      }
    end

    before do
      allow_next_instance_of(::Analytics::AiAnalytics::AiUserMetricsService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: query_double)
        )
      end
      allow(ClickHouse::Client).to receive(:select).with(query_double, :main).and_return(clickhouse_rows)
    end

    it 'returns the total event count from the service' do
      result = batch_sync do
        resolve_field(:total_event_count, object, ctx: context)
      end

      expect(result).to eq(25)
    end

    it 'calls the service with all_features parameter' do
      expect(::Analytics::AiAnalytics::AiUserMetricsService).to receive(:new).with(
        hash_including(feature: :all_features)
      ).and_call_original

      batch_sync { resolve_field(:total_event_count, object, ctx: context) }
    end

    context 'when no metrics are available for the user' do
      let(:clickhouse_rows) { [] }

      it 'returns 0' do
        result = batch_sync do
          resolve_field(:total_event_count, object, ctx: context)
        end

        expect(result).to eq(0)
      end
    end

    context 'when service returns an error' do
      before do
        allow_next_instance_of(::Analytics::AiAnalytics::AiUserMetricsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'ClickHouse unavailable')
          )
        end
      end

      it 'returns 0' do
        result = batch_sync do
          resolve_field(:total_event_count, object, ctx: context)
        end

        expect(result).to eq(0)
      end
    end
  end
end
