# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiMetrics', :click_house, :aggregate_failures, :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers
  include ClickHouseHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.reload.project_namespace }
  let_it_be(:current_user) { create(:user, reporter_of: group) }
  let_it_be(:other_user) { create(:user, developer_of: group) }

  let(:ai_metrics_fields) { query_graphql_field(:aiMetrics, filter_params, fields) }
  let(:filter_params) { {} }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_pro_ai_analytics, anything)
      .and_return(true)
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai metrics' do
    let(:from) { 14.days.ago.to_date }
    let(:to) { 1.day.ago.to_date }
    let(:filter_params) { { startDate: from, endDate: to } }

    let(:fields) do
      <<~FIELDS
        codeSuggestionsContributorsCount
        codeContributorsCount
        codeSuggestionsShownCount
        codeSuggestionsAcceptedCount
        duoChatContributorsCount
        duoUsedCount
        rootCauseAnalysisUsersCount
        codeSuggestions(languages: ["ruby"], ideNames: ["ide1"]) {
          shownCount
          acceptedCount
          contributorsCount
          ideNames
          languages
          shownLinesOfCode
          acceptedLinesOfCode
        }
        codeReview {
          encounterDuoCodeReviewErrorDuringReviewEventCount
          findNoIssuesDuoCodeReviewAfterReviewEventCount
          findNothingToReviewDuoCodeReviewOnMrEventCount
          postCommentDuoCodeReviewOnDiffEventCount
          reactThumbsUpOnDuoCodeReviewCommentEventCount
          reactThumbsDownOnDuoCodeReviewCommentEventCount
          requestReviewDuoCodeReviewOnMrByAuthorEventCount
          requestReviewDuoCodeReviewOnMrByNonAuthorEventCount
          excludedFilesFromDuoCodeReviewEventCount
        }
        chat {
          requestDuoChatResponseEventCount
        }
        troubleshoot {
          troubleshootJobEventCount
        }
        mcp {
          startMcpToolCallEventCount
          finishMcpToolCallEventCount
        }
        agentPlatform(flowTypes: ["chat"], not: { flowTypes: ["pipeline"] }) {
          createdSessionEventCount
          startedSessionEventCount
          finishedSessionEventCount
          droppedSessionEventCount
          stoppedSessionEventCount
          resumedSessionEventCount
          flowMetrics {
            flowType
            sessionsCount
            medianExecutionTime
            usersCount
            completionRate
          }
          userFlowCounts {
            nodes {
              user { username }
              flowType
              sessionsCount
            }
          }
        }
      FIELDS
    end

    context 'with no data' do
      before do
        post_graphql(query, current_user: current_user)
      end

      it 'returns zero counts for all metrics' do
        all_counts = ai_metrics.except('codeSuggestions', 'codeReview', 'chat',
          'troubleshoot', 'mcp', 'agentPlatform')
        expect(all_counts.values).to all(eq(0))

        expect(ai_metrics['codeSuggestions'].except('ideNames', 'languages').values).to all(eq(0))

        expect(ai_metrics['codeReview'].values).to all(eq(0))
        expect(ai_metrics['chat'].values).to all(eq(0))
        expect(ai_metrics['troubleshoot'].values).to all(eq(0))
        expect(ai_metrics['mcp'].values).to all(eq(0))

        agent = ai_metrics['agentPlatform']
        expect(agent.except('flowMetrics', 'userFlowCounts').values).to all(eq(0))
        expect(agent['flowMetrics']).to eq([])
        expect(agent['userFlowCounts']).to eq({ 'nodes' => [] })
      end
    end

    context 'with data' do
      def ai_event_for(user, event:, timestamp:, extras: {})
        { user_id: user.id, namespace_path: namespace.traversal_path(with_organization: false),
          event: Ai::UsageEvent.events[event], extras: extras, timestamp: timestamp }
      end

      before do
        code_suggestion_events = [
          ai_event_for(current_user, event: 'code_suggestion_shown_in_ide',
            extras: { language: 'ruby', ide_name: 'ide1', suggestion_size: 10 },
            timestamp: to - 3.days),
          ai_event_for(current_user, event: 'code_suggestion_accepted_in_ide',
            extras: { language: 'ruby', ide_name: 'ide1', suggestion_size: 20 },
            timestamp: to - 3.days + 1.second),
          ai_event_for(other_user, event: 'code_suggestion_shown_in_ide',
            extras: { language: 'go', ide_name: 'ide2', suggestion_size: 30 },
            timestamp: to - 2.days)
        ]

        duo_chat_and_troubleshoot_events = [
          ai_event_for(current_user, event: 'request_duo_chat_response', timestamp: to - 2.days),
          ai_event_for(current_user, event: 'troubleshoot_job', timestamp: to - 2.days),
          ai_event_for(other_user, event: 'troubleshoot_job', timestamp: to - 1.day)
        ]

        code_review_events = [
          ai_event_for(current_user, event: 'encounter_duo_code_review_error_during_review', timestamp: to - 2.days),
          ai_event_for(current_user, event: 'post_comment_duo_code_review_on_diff', timestamp: to - 2.days),
          ai_event_for(other_user, event: 'post_comment_duo_code_review_on_diff', timestamp: to - 1.day)
        ]

        mcp_events = [
          ai_event_for(current_user, event: 'start_mcp_tool_call', timestamp: to - 2.days),
          ai_event_for(current_user, event: 'finish_mcp_tool_call', timestamp: to - 2.days)
        ]

        agent_platform_events = [
          ai_event_for(current_user, event: 'agent_platform_session_created',
            extras: { session_id: 1, flow_type: 'chat' },
            timestamp: to - 3.days),
          ai_event_for(current_user, event: 'agent_platform_session_started',
            extras: { session_id: 1, flow_type: 'chat' },
            timestamp: to - 3.days + 5.seconds),
          ai_event_for(current_user, event: 'agent_platform_session_finished',
            extras: { session_id: 1, flow_type: 'chat' },
            timestamp: to - 3.days + 30.seconds)
        ]

        clickhouse_fixture(:ai_usage_events,
          code_suggestion_events +
          duo_chat_and_troubleshoot_events +
          code_review_events +
          mcp_events +
          agent_platform_events
        )

        insert_events_into_click_house([
          build_stubbed(:event, :pushed, project: project, author: current_user, created_at: to - 1.day),
          build_stubbed(:event, :pushed, project: project, author: other_user, created_at: to - 2.days)
        ])

        post_graphql(query, current_user: current_user)
      end

      it 'returns correct usage event counts' do
        expect(ai_metrics).to include('duoUsedCount' => 2, 'rootCauseAnalysisUsersCount' => 2)

        expect(ai_metrics['codeReview']).to include(
          'encounterDuoCodeReviewErrorDuringReviewEventCount' => 1,
          'postCommentDuoCodeReviewOnDiffEventCount' => 2,
          'findNoIssuesDuoCodeReviewAfterReviewEventCount' => 0
        )

        expect(ai_metrics['chat']).to eq('requestDuoChatResponseEventCount' => 1)
        expect(ai_metrics['troubleshoot']).to eq('troubleshootJobEventCount' => 2)
        expect(ai_metrics['mcp']).to eq('startMcpToolCallEventCount' => 1, 'finishMcpToolCallEventCount' => 1)
      end

      it 'returns agent platform metrics filtered by flow type' do
        expect(ai_metrics['agentPlatform']).to include(
          'createdSessionEventCount' => 1,
          'startedSessionEventCount' => 1,
          'finishedSessionEventCount' => 1,
          'droppedSessionEventCount' => 0
        )

        expect(ai_metrics['agentPlatform']['flowMetrics']).to contain_exactly(
          hash_including('flowType' => 'chat', 'sessionsCount' => 1, 'usersCount' => 1, 'completionRate' => 100.0)
        )

        expect(ai_metrics['agentPlatform']['userFlowCounts']['nodes']).to contain_exactly(
          hash_including('flowType' => 'chat', 'sessionsCount' => 1,
            'user' => { 'username' => current_user.username })
        )
      end

      it 'returns code suggestion metrics filtered by language and IDE' do
        expect(ai_metrics['codeSuggestions']).to include(
          'contributorsCount' => 1,
          'shownCount' => 1,
          'acceptedCount' => 1,
          'shownLinesOfCode' => 10,
          'acceptedLinesOfCode' => 20
        )

        expect(ai_metrics['codeSuggestions']['languages']).to contain_exactly('ruby')
        expect(ai_metrics['codeSuggestions']['ideNames']).to contain_exactly('ide1')
      end
    end

    where(:filter_params, :error_message) do
      { startDate: '2024-07-01'.to_date, endDate: '2024-06-30'.to_date } | "start date cannot be after end date"
      { startDate: 5.years.ago } | "maximum date range is 1 year"
    end

    with_them do
      before do
        post_graphql(query, current_user: current_user)
      end

      it 'returns an error' do
        expect_graphql_errors_to_include(error_message)
        expect(ai_metrics).to be_nil
      end
    end

    context 'when ClickHouse is unavailable' do
      let(:fields) { 'codeContributorsCount duoUsedCount' }

      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        post_graphql(query, current_user: current_user)
      end

      it 'returns nil for all metric fields' do
        expect(ai_metrics).to eq('codeContributorsCount' => nil, 'duoUsedCount' => nil)
      end
    end
  end

  context 'for group' do
    let_it_be(:namespace) { group }
    let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_metrics_fields) }
    let(:ai_metrics) { graphql_data['group']['aiMetrics'] }

    it_behaves_like 'common ai metrics'
  end

  context 'for project' do
    let_it_be(:namespace) { project_namespace }
    let(:query) { graphql_query_for(:project, { fullPath: project.full_path }, ai_metrics_fields) }
    let(:ai_metrics) { graphql_data['project']['aiMetrics'] }

    it_behaves_like 'common ai metrics'
  end
end
