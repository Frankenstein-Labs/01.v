# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Duo Panel Integration (GraphQL fixtures)', type: :request, feature_category: :duo_chat do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers
  include Ai::Catalog::TestHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }

  let_it_be(:thread_with_messages, freeze: false) do
    create(:ai_conversation_thread, user: user, conversation_type: :duo_chat,
      last_updated_at: 2.hours.ago)
  end

  let_it_be(:empty_thread, freeze: false) do
    create(:ai_conversation_thread, user: user, conversation_type: :duo_chat,
      last_updated_at: 1.day.ago)
  end

  let_it_be(:user_message, freeze: false) do
    create(:ai_conversation_message, thread: thread_with_messages, role: :user,
      content: 'How do I refactor this function?')
  end

  let_it_be(:assistant_message, freeze: false) do
    create(:ai_conversation_message, :assistant, thread: thread_with_messages,
      content: 'You can extract the inner loop into a helper.')
  end

  let_it_be(:agent_a, freeze: false) { create(:ai_catalog_agent, :public, project: project) }
  let_it_be(:agent_a_version, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent_a, version: '1.0.0',
      definition: { 'system_prompt' => 'Security agent', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_a_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_agent,
      item: agent_a, project: project, pinned_version_prefix: '1.0.0')
  end

  let_it_be(:agent_b, freeze: false) { create(:ai_catalog_agent, :public, project: project) }
  let_it_be(:agent_b_version, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent_b, version: '1.0.0',
      definition: { 'system_prompt' => 'Planning agent', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_b_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_agent,
      item: agent_b, project: project, pinned_version_prefix: '1.0.0')
  end

  base_output_path = 'graphql/ai_duo_panel/integration/'

  before_all do
    project.add_maintainer(user)
  end

  before do
    enable_ai_catalog
    stub_licensed_features(ai_catalog: true, ai_features: true)
    # The foundational-agents resolver branches on SaaS detection. Force the
    # namespace branch so the project's root namespace governs the agent list,
    # rather than relying on a default-organization global that isn't seeded here.
    stub_saas_features(gitlab_com_subscriptions: true)
    # User-level Duo chat access is gated by ChatAuthorizer; stub to keep fixtures
    # deterministic regardless of license/cloud-connector state in test env.
    allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
      .to receive(:user)
      .and_return(::Gitlab::Llm::Utils::Authorizer::Response.new(allowed: true))
    sign_in(user)
  end

  describe GraphQL::Query, 'duo_chat_available' do
    it "#{base_output_path}duo_chat_available.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/duo_chat_available.query.graphql', ee: true)
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end
  end

  describe GraphQL::Query, 'conversation threads and messages' do
    it "#{base_output_path}get_ai_conversation_threads.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_ai_conversation_threads.query.graphql', ee: true)
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_ai_messages_with_thread.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_ai_messages_with_thread.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: { threadId: thread_with_messages.to_global_id.to_s })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_ai_messages_with_thread_empty.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_ai_messages_with_thread.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: { threadId: empty_thread.to_global_id.to_s })
      expect_graphql_errors_to_be_empty
    end
  end

  describe GraphQL::Query, 'agents' do
    it "#{base_output_path}get_configured_agents.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_configured_agents.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: {
        projectId: project.to_global_id.to_s,
        groupId: group.to_global_id.to_s,
        includeFoundationalConsumers: false,
        first: 25
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_foundational_chat_agents.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_foundational_chat_agents.graphql', ee: true)
      post_graphql(query, current_user: user, variables: { projectId: project.to_global_id.to_s })
      expect_graphql_errors_to_be_empty
    end
  end

  describe GraphQL::Query, 'mutations' do
    # `chat` and `dismissUserCallout` are intentionally not generated here: their
    # response shapes are input-dependent (echoing requestId/threadId/featureName),
    # so they remain as small dynamic handlers in the MSW handler file.

    it "#{base_output_path}delete_conversation_thread.mutation.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/delete_conversation_thread.mutation.graphql', ee: true)
      post_graphql(query, current_user: user, variables: {
        input: { threadId: empty_thread.to_global_id.to_s }
      })
      expect_graphql_errors_to_be_empty
    end
  end

  # The following queries fire automatically when the real DuoAgenticChatStateManager
  # is mounted in the panel. We generate empty/default fixtures so MSW has a handler
  # to return; the test doesn't assert on their values, it just needs them to resolve.
  describe GraphQL::Query, 'state manager bootstrap queries' do
    # Filename matches the GraphQL operation name (`getUserWorkflows`, plural)
    # rather than the source file path (`get_user_workflow.query.graphql`, singular).
    # `loadFixturesMap` keys fixtures by camelCased filename, so this drift between
    # source path and operation name has to be reconciled here.
    it "#{base_output_path}get_user_workflows.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_user_workflow.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: { type: 'foundational_chat_agents', first: 99_999 })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_ai_chat_context_presets.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_ai_chat_context_presets.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: {
        projectId: project.to_global_id.to_s,
        url: 'http://localhost/',
        questionCount: 4
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_agent_flow_config.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_agent_flow_config.query.graphql', ee: true)
      post_graphql(query, current_user: user, variables: {
        agentVersionId: agent_a_version.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    # Filename matches the GraphQL operation name (`getGitlabCreditsStatus`) so
    # `loadFixturesMap` keys it to the operation the panel handler serves.
    it "#{base_output_path}get_gitlab_credits_status.query.graphql.json" do
      # The DuoChat credits check requires cloud-connector wiring that's not
      # set up in the fixture-generator environment. Stub the helper so the
      # response is deterministic.
      allow_next_instance_of(::Gitlab::Llm::DuoChat) do |bot|
        allow(bot).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
      end

      query = get_graphql_query_as_string('ai/graphql/get_gitlab_credits_status.query.graphql', ee: true)
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end
  end
end
