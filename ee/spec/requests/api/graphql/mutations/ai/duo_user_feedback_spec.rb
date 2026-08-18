# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DuoUserFeedback', feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:thread) { create(:ai_conversation_thread, user: user) }
  let(:current_user) { user }
  let(:messages) { create_list(:ai_conversation_message, 3, thread: thread) }
  let(:ai_message_id) { messages.first.message_xid }
  let(:input) { { ai_message_id: ai_message_id } }
  let(:mutation) { graphql_mutation(:duo_user_feedback, input) }
  let(:request_id) { messages.first.request_id }

  subject(:resolve) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples "process feedback" do
    it 'marks the message as having feedback' do
      resolve

      expect(messages.first.reload.has_feedback).to be(true)
    end

    context 'without a user' do
      let(:current_user) { nil }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with a non-existing message id' do
      let(:ai_message_id) { 'non-existing' }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with tracking event data' do
      let(:category) { 'ask_gitlab_chat' }
      let(:action) { 'click_button' }
      let(:label) { 'response_feedback' }
      let(:property) { 'useful,not_relevant' }
      let(:extra) do
        { 'improveWhat' => 'more examples', 'didWhat' => 'provided clarity', 'promptLocation' => 'after_content' }
      end

      let(:event) { { category: category, action: action, label: label, property: property, extra: extra } }
      let(:input) { { ai_message_id: ai_message_id, tracking_event: event } }

      it 'tracks the feedback event' do
        resolve

        expect_snowplow_event(
          category: category,
          action: action,
          label: label,
          property: property,
          user: current_user,
          requestId: request_id,
          cleanedUrl: nil,
          **extra
        )
      end

      context 'with unexpected `extra` keys' do
        let(:extra) do
          { 'improveWhat' => 'more examples', 'user' => '1' }
        end

        it 'omits the unexpected keys' do
          resolve

          expect_snowplow_event(
            category: category,
            action: action,
            label: label,
            property: property,
            user: current_user,
            requestId: request_id,
            cleanedUrl: nil,
            'improveWhat' => 'more examples'
          )
        end
      end

      context 'with referer url' do
        let(:headers) { { 'Referer' => referer_url } }
        let_it_be(:namespace) { create(:group, path: 'namespace') }
        let_it_be(:project) { create(:project, namespace: namespace, path: 'project') }

        shared_examples 'tracks the feedback event with cleaned url' do
          it 'tracks the event with cleaned url' do
            post_graphql(
              mutation.query,
              current_user: current_user,
              variables: mutation.variables,
              headers: headers
            )

            expect_snowplow_event(
              category: category,
              action: action,
              label: label,
              property: property,
              user: current_user,
              requestId: request_id,
              cleanedUrl: expected_cleaned_url,
              **extra
            )
          end
        end

        context 'when cleaning issue URL' do
          let_it_be(:issue) { create(:issue, project: project) }
          let(:referer_url) { "http://localhost/#{project.full_path}/-/issues/#{issue.iid}" }
          let(:expected_cleaned_url) { '/namespace/project/-/issues/' }

          it_behaves_like 'tracks the feedback event with cleaned url'
        end

        context 'when removing extra slashes caused by removing IDs' do
          let_it_be(:merge_request) { create(:merge_request, source_project: project) }
          let(:referer_url) { "http://localhost/#{project.full_path}/-/merge_requests/#{merge_request.iid}/diffs" }
          let(:expected_cleaned_url) { '/namespace/project/-/merge_requests/diffs' }

          it_behaves_like 'tracks the feedback event with cleaned url'
        end

        context 'when invalid URL is provided' do
          let_it_be(:merge_request) { create(:merge_request, source_project: project) }
          let(:referer_url) { "test" }
          let(:expected_cleaned_url) { nil }

          it_behaves_like 'tracks the feedback event with cleaned url'
        end
      end
    end
  end

  it_behaves_like "process feedback"
end
