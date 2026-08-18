# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Metrics (GraphQL fixtures)', feature_category: :value_stream_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group, freeze: false) { create(:group, name: 'cool-group') }
  let_it_be(:current_user, freeze: false) { create(:user, reporter_of: group) }

  describe GraphQL::Query, type: :request do
    include GraphqlHelpers

    let(:base_ai_metrics_payload) do
      {
        duo_chat_contributors_count: 5,
        duo_used_count: 3,
        root_cause_analysis_users_count: 4
      }
    end

    let(:base_code_suggestion_payload) do
      {
        contributors_count: 5,
        shown_count: 5,
        accepted_count: 2,
        languages: %w[js ruby go],
        ide_names: %w[VSCode Neovim RubyMine],
        accepted_lines_of_code: 30,
        shown_lines_of_code: 70
      }
    end

    let(:base_usage_event_count_payload) do
      {
        post_comment_duo_code_review_on_diff_event_count: 100,
        react_thumbs_up_on_duo_code_review_comment_event_count: 320,
        react_thumbs_down_on_duo_code_review_comment_event_count: 80,
        request_review_duo_code_review_on_mr_by_author_event_count: 100,
        request_review_duo_code_review_on_mr_by_non_author_event_count: 100
      }
    end

    let(:base_agent_platform_payload) do
      {
        created_session_event_count: 25
      }
    end

    let(:start_date) { '2025-01-01'.to_date }
    let(:end_date) { '2025-12-31'.to_date }
    let(:filter_params) { { from: start_date, to: end_date } }

    query_path = 'analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql'

    shared_examples 'AI metrics fixture' do |fixture_name|
      before do
        allow_next_instance_of(::Analytics::AiAnalytics::AiMetricsService,
          current_user, hash_including(filter_params)) do |instance|
          allow(instance).to receive(:execute)
                               .and_return(ServiceResponse.success(payload: ai_metrics_service_payload))
        end

        allow_next_instance_of(::Analytics::AiAnalytics::CodeSuggestionUsageService,
          current_user, hash_including(filter_params)) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.success(payload: code_suggestion_payload)
          )
        end

        allow_next_instance_of(::Analytics::AiAnalytics::UsageEventCountService,
          current_user, hash_including(filter_params)) do |instance|
          allow(instance).to receive(:execute)
                               .and_return(ServiceResponse.success(payload: usage_event_count_service_payload))
        end

        allow_next_instance_of(::Analytics::AiAnalytics::AgentPlatform::EventCountService,
          current_user, hash_including(filter_params)) do |instance|
          allow(instance).to receive(:execute)
                               .and_return(ServiceResponse.success(payload: agent_platform_event_count_service_payload))
        end

        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                            .with(current_user, :read_pro_ai_analytics, anything)
                            .and_return(true)
      end

      it "ee/graphql/#{query_path}#{fixture_name.present? ? ".#{fixture_name}" : ''}.json" do
        query = get_graphql_query_as_string(query_path)
        post_graphql(query, current_user: current_user,
          variables: { fullPath: group.full_path, startDate: start_date, endDate: end_date })

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with default values' do
      let(:ai_metrics_service_payload) { base_ai_metrics_payload }
      let(:code_suggestion_payload) { base_code_suggestion_payload }
      let(:usage_event_count_service_payload) { base_usage_event_count_payload }
      let(:agent_platform_event_count_service_payload) { base_agent_platform_payload }

      it_behaves_like 'AI metrics fixture'
    end

    # Fixtures for Duo usage metrics comparison table columns 2-6.
    # These correspond to different data multipliers to test various metric values.
    # Update this range if the table structure changes or new columns are added.
    (2..6).each do |index|
      context "for usage metrics table column #{index}" do
        let(:ai_metrics_service_payload) { multiply_payload(base_ai_metrics_payload, index) }
        let(:code_suggestion_payload) { multiply_payload(base_code_suggestion_payload, index) }
        let(:usage_event_count_service_payload) { multiply_payload(base_usage_event_count_payload, index) }
        let(:agent_platform_event_count_service_payload) { multiply_payload(base_agent_platform_payload, index) }

        it_behaves_like 'AI metrics fixture', "column_#{index}"
      end
    end

    context 'with zero values' do
      let(:ai_metrics_service_payload) { zero_payload(base_ai_metrics_payload) }
      let(:code_suggestion_payload) { zero_payload(base_code_suggestion_payload) }
      let(:usage_event_count_service_payload) { zero_payload(base_usage_event_count_payload) }
      let(:agent_platform_event_count_service_payload) { zero_payload(base_agent_platform_payload) }

      it_behaves_like 'AI metrics fixture', 'zero_values'
    end

    context 'with null values' do
      let(:ai_metrics_service_payload) { null_payload(base_ai_metrics_payload) }
      let(:code_suggestion_payload) { null_payload(base_code_suggestion_payload) }
      let(:usage_event_count_service_payload) { null_payload(base_usage_event_count_payload) }
      let(:agent_platform_event_count_service_payload) { null_payload(base_agent_platform_payload) }

      it_behaves_like 'AI metrics fixture', 'null_values'
    end

    context 'with unknown/unsupported code suggestion dimensions' do
      let(:ai_metrics_service_payload) { base_ai_metrics_payload }
      let(:code_suggestion_payload) do
        base_code_suggestion_payload.merge(
          languages: %w[js ts] + [''],
          ide_names: %w[GoLand WebStorm] + [''])
      end

      let(:usage_event_count_service_payload) { base_usage_event_count_payload }
      let(:agent_platform_event_count_service_payload) { base_agent_platform_payload }

      it_behaves_like 'AI metrics fixture', 'empty_code_suggestion_dimensions'
    end

    private

    def multiply_payload(payload, multiplier)
      payload.transform_values { |v| v.is_a?(Integer) ? v * multiplier : v }
    end

    def zero_payload(payload)
      payload.transform_values do |v|
        v.is_a?(Array) ? [] : 0
      end
    end

    def null_payload(payload)
      payload.transform_values do |v|
        v.is_a?(Array) ? [] : nil
      end
    end
  end
end
