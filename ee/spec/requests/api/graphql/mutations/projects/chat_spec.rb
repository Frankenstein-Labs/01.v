# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'AiAction for chat', :saas, :with_current_organization, feature_category: :shared do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user, organizations: [current_organization], developer_of: [project, group]) }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:thread) { create(:ai_conversation_thread, user: current_user, organization: current_organization) }
  let(:params) { { chat: { resource_id: resource&.to_gid, content: "summarize" }, thread_id: thread.to_gid } }

  let(:mutation) do
    graphql_mutation(:ai_action, params) do
      <<-QL.strip_heredoc
        errors
      QL
    end
  end

  before do
    # Since this doesn't go through a request flow, we need to manually set Current.organization
    Current.organization = current_organization
  end

  include_context 'with ai features enabled for group'

  it 'logs GraphQL mutation query and variables' do
    expect_next_instance_of(Mutations::Ai::Action) do |mutation|
      expect(mutation).to receive(:log_conditional_info).with(
        instance_of(User),
        hash_including(
          graphql_query_string: instance_of(String),
          graphql_variables: instance_of(Hash)
        )
      )
    end

    post_graphql_mutation(mutation, current_user: current_user)
  end

  context 'when expanded_ai_logging feature flag is disabled' do
    before do
      stub_feature_flags(expanded_ai_logging: false)
    end

    it 'does not log GraphQL mutation query and variables' do
      expect_next_instance_of(Mutations::Ai::Action) do |mutation|
        expect(mutation).to receive(:log_conditional_info).with(
          instance_of(User),
          hash_excluding(:graphql_query_string, :graphql_variables)
        )
      end

      post_graphql_mutation(mutation, current_user: current_user)
    end
  end

  context 'when resource is nil' do
    let(:resource) { nil }

    it 'successfully performs a chat request' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize",
          thread: thread),
        hash_including(referer_url: nil)
      )

      post_graphql_mutation(mutation, current_user: current_user)
    end
  end

  context 'when resource is an issue' do
    it 'successfully performs a request' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize",
          thread: thread),
        hash_including(referer_url: nil)
      )

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
    end
  end

  context 'when resource is a user' do
    let_it_be_with_reload(:resource) { current_user }

    it 'successfully performs a request' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize",
          thread: thread),
        hash_including(referer_url: nil)
      )

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
    end
  end

  context 'when current_file is present' do
    let(:current_file) { { selected_text: 'selected', content_above_cursor: 'prefix', file_name: 'test.py' } }
    let(:params) { { chat: { resource_id: resource&.to_gid, content: "summarize", current_file: current_file } } }

    it 'successfully performs a chat request' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize"),
        hash_including(current_file: current_file)
      )

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
    end
  end

  context 'when additional_context is present' do
    let(:additional_context) do
      [
        { category: 'SNIPPET', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
      ]
    end

    let(:expected_additional_context) do
      [
        { category: 'snippet', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
      ]
    end

    let(:params) do
      { chat: { resource_id: resource&.to_gid, content: "summarize", additional_context: additional_context },
        thread_id: thread.to_gid }
    end

    it 'successfully performs a chat request' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize"),
        hash_including(additional_context: expected_additional_context)
      )

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
    end

    it 'stores additional context into chat history' do
      expect(Llm::CompletionWorker).to receive(:perform_for).with(
        an_object_having_attributes(
          user: current_user,
          resource: resource,
          ai_action: :chat,
          content: "summarize"),
        hash_including(additional_context: expected_additional_context)
      )

      post_graphql_mutation(mutation, current_user: current_user)

      last_message = Gitlab::Llm::ChatStorage.new(current_user, thread).messages.last
      expect(last_message.extras['additional_context']).to eq(expected_additional_context.map(&:stringify_keys))
    end
  end
end
