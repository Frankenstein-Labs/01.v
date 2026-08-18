# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user AI messages', :clean_gitlab_redis_cache, feature_category: :shared do
  include GraphqlHelpers

  let_it_be(:organization, freeze: false) { current_organization }
  let_it_be(:user, freeze: false) { create(:user, organizations: [organization]) }
  let_it_be(:thread, freeze: false) do
    create(:ai_conversation_thread, user: user, conversation_type: 'duo_chat', organization: organization)
  end

  let_it_be(:other_user, freeze: false) { create(:user, organizations: [organization]) }
  let_it_be(:other_thread, freeze: false) do
    create(:ai_conversation_thread, user: other_user, organization: organization)
  end

  let_it_be(:external_issue, freeze: false) { create(:issue) }
  let_it_be(:external_issue_url, freeze: false) { ::Gitlab::UrlBuilder.instance.issue_url(external_issue) }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        requestId
        content
        contentHtml
        role
        timestamp
        errors
        extras {
          additionalContext {
            category
            id
            content
            metadata
          }
        }
      }
    GRAPHQL
  end

  let(:arguments) { { requestIds: 'uuid1', threadId: thread.to_global_id.to_s } }
  let(:query) { graphql_query_for('aiMessages', arguments, fields) }

  let(:response_content) do
    "response #{external_issue_url}+"
  end

  subject { graphql_data.dig('aiMessages', 'nodes') }

  before do
    create(
      :ai_chat_message,
      request_id: 'uuid1',
      role: 'user',
      content: 'question 1',
      user: user,
      thread: thread,
      extras: {
        additional_context: [
          { category: 'file', id: 'hello.rb', content: 'puts "hello"', metadata: { "file_name" => "hello.rb" } }
        ]
      }
    )
    create(:ai_chat_message, request_id: 'uuid1', role: 'assistant', content: response_content, user: user,
      thread: thread)
    # should not be included in response because it's for other user
    create(:ai_chat_message, request_id: 'uuid1', role: 'user', content: 'question 2', user: other_user,
      thread: other_thread)
  end

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty array' do
      post_graphql(query, current_user: current_user)

      expect(subject).to be_empty
    end
  end

  context 'when user is logged in' do
    let(:current_user) { user }

    it 'returns user messages', :freeze_time do
      post_graphql(query, current_user: current_user)

      expect(subject).to eq([
        {
          'requestId' => 'uuid1',
          'content' => 'question 1',
          'contentHtml' => '<p data-sourcepos="1:1-1:10" dir="auto">question 1</p>',
          'role' => 'USER',
          'errors' => [],
          'timestamp' => Time.current.iso8601,
          'extras' => {
            'additionalContext' => [
              {
                'category' => 'FILE',
                'id' => 'hello.rb',
                'content' => 'puts "hello"',
                'metadata' => { "file_name" => "hello.rb" }
              }
            ]
          }
        },
        {
          'requestId' => 'uuid1',
          'content' => response_content,
          'contentHtml' => "<p data-sourcepos=\"1:1-1:#{response_content.size}\" dir=\"auto\">response " \
                           "<a data-sourcepos=\"1:10-1:#{response_content.size}\" " \
                           "href=\"#{external_issue_url}+\">#{external_issue_url}+" \
                           "</a></p>",
          'role' => 'ASSISTANT',
          'errors' => [],
          'timestamp' => Time.current.iso8601,
          'extras' => {
            'additionalContext' => nil
          }
        }
      ])
    end
  end
end
