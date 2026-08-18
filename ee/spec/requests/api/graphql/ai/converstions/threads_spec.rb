# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user AI conversation threads', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:other_user) { create(:user, organizations: [organization]) }
  let_it_be(:thread_1) do
    create(:ai_conversation_thread, user: user, last_updated_at: 1.day.ago).tap do |thread|
      create(:ai_conversation_message, content: 'How are you?', role: :user, thread: thread)
      create(:ai_conversation_message, content: 'I am fine, thank you.', role: :assistant, thread: thread)
    end
  end

  let_it_be(:thread_2) do
    create(:ai_conversation_thread, user: user).tap do |thread|
      create(:ai_conversation_message, content: 'How is the weather today?', role: :user, thread: thread)
      create(:ai_conversation_message, content: 'I am fine, thank you.', role: :assistant, thread: thread)
    end
  end

  let_it_be(:unrelated_thread) do
    create(:ai_conversation_thread, user: other_user).tap do |thread|
      create(:ai_conversation_message, content: 'Unrelated message', role: :user, thread: thread)
      create(:ai_conversation_message, content: 'Unrelated response', role: :assistant, thread: thread)
    end
  end

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        lastUpdatedAt
        createdAt
        conversationType
        title
      }
    GRAPHQL
  end

  let(:arguments) { {} }
  let(:query) { graphql_query_for('aiConversationThreads', arguments, fields) }

  subject(:result) { graphql_data.dig('aiConversationThreads', 'nodes') }

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty array' do
      post_graphql(query, current_user: current_user)

      expect(result).to be_empty
    end
  end

  context 'when user is logged in' do
    let(:current_user) { user }

    it 'returns user threads', :freeze_time do
      post_graphql(query, current_user: current_user)

      expect(result).to eq(
        [
          {
            "conversationType" => "DUO_CHAT",
            "createdAt" => thread_2.created_at.iso8601,
            "id" => thread_2.to_global_id.to_s,
            "lastUpdatedAt" => thread_2.last_updated_at.iso8601,
            "title" => thread_2.messages.ordered.first.content
          },
          {
            "conversationType" => "DUO_CHAT",
            "createdAt" => thread_1.created_at.iso8601,
            "id" => thread_1.to_global_id.to_s,
            "lastUpdatedAt" => thread_1.last_updated_at.iso8601,
            "title" => thread_1.messages.ordered.first.content
          }
        ]
      )
    end

    it 'avoids N+1 database queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_graphql(query, current_user: current_user) }
      threads = create_list(:ai_conversation_thread, 5, user: user)
      threads.each { |t| create(:ai_conversation_message, thread: t) }
      expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control).or_fewer
    end
  end
end
