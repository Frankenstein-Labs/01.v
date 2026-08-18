# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackEvents::AppMentionedService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:slack_installation) { create(:slack_integration) }
    let_it_be(:user) { create(:user) }
    let_it_be(:chat_name) do
      create(:chat_name, user: user, team_id: slack_installation.team_id, chat_id: 'U0123ABCDEF')
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:service_account) { create(:user, :service_account) }

    let(:slack_workspace_id) { slack_installation.team_id }
    let(:slack_user_id) { chat_name.chat_id }
    let(:channel_id) { 'C0123ABCDEF' }
    let(:message_ts) { '1234567890.123456' }
    let(:event_text) { "<@#{slack_installation.bot_user_id}> hello world" }

    let(:params) do
      {
        team_id: slack_workspace_id,
        event: {
          user: slack_user_id,
          channel: channel_id,
          ts: message_ts,
          text: event_text
        }
      }
    end

    let(:reactions_add_url) { "#{Slack::API::BASE_URL}/reactions.add" }
    let(:reactions_remove_url) { "#{Slack::API::BASE_URL}/reactions.remove" }
    let(:post_message_url) { "#{Slack::API::BASE_URL}/chat.postMessage" }
    let(:post_ephemeral_url) { "#{Slack::API::BASE_URL}/chat.postEphemeral" }
    let(:conversations_replies_url) { "#{Slack::API::BASE_URL}/conversations.replies" }
    let(:conversations_info_url) { "#{Slack::API::BASE_URL}/conversations.info" }

    let(:mock_workflow) { instance_double(Ai::DuoWorkflows::Workflow, id: 1) }
    let(:trigger_result) { ServiceResponse.success(payload: { workflow: mock_workflow }) }
    let(:mock_adapter) do
      instance_double(
        Ai::Messaging::Adapters::Slack,
        trigger: trigger_result,
        build_callback_context: { 'team_id' => slack_workspace_id, 'channel_id' => channel_id,
                                  'thread_ts' => message_ts, 'message_ts' => message_ts,
                                  'user_id' => slack_user_id },
        deliver_error: nil
      )
    end

    let(:resolver_result) do
      ServiceResponse.success(payload: {
        project: project,
        service_account: service_account,
        flow_config_id: 'developer',
        flow_config_schema_version: 'v1',
        flow_version: nil
      })
    end

    let(:thread_replies_response) do
      {
        ok: true,
        messages: [
          { user: slack_user_id, text: event_text, ts: message_ts },
          { user: 'U_OTHER', text: 'a reply', ts: '1234567891.000001' }
        ]
      }
    end

    subject(:execute) { described_class.new(params).execute }

    before do
      stub_feature_flags(slack_duo_agent: user)
      allow_next_instance_of(ChatNames::FindUserService) do |service|
        allow(service).to receive(:execute).and_return(chat_name)
      end
      allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform).and_return(true)

      stub_request(:post, reactions_add_url).to_return(status: 200, body: { ok: true }.to_json,
        headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, reactions_remove_url).to_return(status: 200, body: { ok: true }.to_json,
        headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, post_message_url).to_return(status: 200, body: { ok: true }.to_json,
        headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, post_ephemeral_url).to_return(status: 200, body: { ok: true }.to_json,
        headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, conversations_replies_url).with(query: hash_including({}))
        .to_return(status: 200, body: thread_replies_response.to_json,
          headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, conversations_info_url).with(query: hash_including({}))
        .to_return(status: 200,
          body: { ok: true, channel: { id: channel_id, is_channel: true, is_private: false } }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      # Stub the resolver and adapter trigger
      allow_next_instance_of(Ai::Messaging::DefaultProjectFlowResolver) do |resolver|
        allow(resolver).to receive(:execute).and_return(resolver_result)
      end
      allow(Ai::Messaging::Adapters::Slack).to receive(:new).and_return(mock_adapter)
    end

    describe 'privacy notice gating on the default Duo namespace' do
      let_it_be(:group) { create(:group) }

      before do
        stub_request(:get, conversations_info_url).with(query: hash_including({}))
          .to_return(status: 200,
            body: { ok: true, channel: { id: channel_id, is_private: true } }.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      context 'when the user has a default Duo namespace' do
        before do
          allow(user).to receive(:default_duo_namespace).and_return(group)
        end

        it 'posts the privacy notice in a private channel instead of triggering the flow' do
          expect(mock_adapter).not_to receive(:trigger)

          is_expected.to be_success

          expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
            body: a_string_including(described_class::PRIVACY_NOTICE_ACKNOWLEDGE_ACTION_ID)
          )
        end
      end

      context 'when the user has no default Duo namespace' do
        let(:resolver_result) do
          ServiceResponse.error(message: 'No default Duo namespace configured', reason: :namespace_not_configured)
        end

        before do
          allow(user).to receive(:default_duo_namespace).and_return(nil)
        end

        it 'skips the notice and lets the resolver error surface' do
          expect(mock_adapter).to receive(:deliver_error).with(
            callback_context: anything,
            error: :namespace_not_configured
          )

          is_expected.to be_success

          expect(WebMock).not_to have_requested(:get, conversations_info_url)
          expect(WebMock).not_to have_requested(:post, post_ephemeral_url).with(
            body: a_string_including(described_class::PRIVACY_NOTICE_ACKNOWLEDGE_ACTION_ID)
          )
        end
      end
    end

    it 'triggers a Duo flow via the Slack adapter' do
      expect(mock_adapter).to receive(:trigger).with(
        an_instance_of(Ai::Messaging::Adapters::Base::TriggerBundle)
      ).and_return(trigger_result)

      is_expected.to be_success
    end

    it 'builds the TriggerBundle with correct params', :aggregate_failures do
      expect(mock_adapter).to receive(:trigger) do |bundle|
        expect(bundle.current_user).to eq(user)
        expect(bundle.service_account).to eq(service_account)
        expect(bundle.flow_reference).to eq('developer/v1')
        expect(bundle.project).to eq(project)
        expect(bundle.goal).to include('<conversation>')
        expect(bundle.goal).to include('standard Markdown')
        expect(bundle.goal).to include('Always write links as [text](url)')
        trigger_result
      end

      execute
    end

    it 'passes the correct flow_reference to the resolver' do
      expect(Ai::Messaging::DefaultProjectFlowResolver).to receive(:new).with(
        flow_reference: 'developer/v1',
        current_user: user
      ).and_call_original

      execute
    end

    describe 'resolver failure errors' do
      using RSpec::Parameterized::TableSyntax

      where(:reason, :expected_error) do
        :namespace_not_configured | :namespace_not_configured
        :flow_not_enabled         | :flow_not_enabled
        :workspace_project_error  | :workspace_project_error
        :service_account_error    | :service_account_error
        nil                       | nil
      end

      with_them do
        let(:resolver_result) do
          ServiceResponse.error(message: 'resolver failed', reason: reason)
        end

        it 'calls deliver_error on the adapter with the resolver reason' do
          expect(mock_adapter).to receive(:deliver_error).with(
            callback_context: anything,
            error: expected_error
          )

          execute
        end
      end
    end

    context 'when adapter.trigger fails' do
      let(:trigger_result) do
        ServiceResponse.error(message: 'workflow creation failed', reason: :execute_workflow_failed)
      end

      it 'logs the failure and still returns success' do
        expect(Gitlab::IntegrationsLogger).to receive(:info).with(
          hash_including(
            message: 'Duo Messaging: flow trigger failed',
            failure_reason: :execute_workflow_failed
          )
        )

        is_expected.to be_success
      end
    end

    context 'when message is a root mention (single message, no existing thread)' do
      it 'fetches thread context to build the goal' do
        is_expected.to be_success

        expect(WebMock).to have_requested(:get, conversations_replies_url).with(
          query: hash_including('channel' => channel_id, 'ts' => message_ts)
        )
      end
    end

    context 'when message is in an existing thread' do
      let(:thread_ts) { '1111111111.000001' }
      let(:params) do
        {
          team_id: slack_workspace_id,
          event: {
            user: slack_user_id,
            channel: channel_id,
            ts: message_ts,
            thread_ts: thread_ts,
            text: event_text
          }
        }
      end

      it 'fetches replies using thread_ts' do
        is_expected.to be_success

        expect(WebMock).to have_requested(:get, conversations_replies_url).with(
          query: hash_including('channel' => channel_id, 'ts' => thread_ts)
        )
      end
    end

    context 'when conversations.replies returns an error' do
      before do
        stub_request(:get, conversations_replies_url).with(query: hash_including({}))
          .to_return(status: 200, body: { ok: false, error: 'channel_not_found' }.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      it 'logs the error and falls back gracefully' do
        expect(Gitlab::IntegrationsLogger).to receive(:error).with(
          hash_including(message: 'Slack API error when fetching thread')
        )

        is_expected.to be_success
      end
    end

    context 'when conversations.replies raises an HTTP error' do
      before do
        stub_request(:get, conversations_replies_url).with(query: hash_including({}))
          .to_raise(Errno::ECONNREFUSED.new('error'))
      end

      it 'tracks the exception and falls back gracefully' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(Errno::ECONNREFUSED), slack_workspace_id: slack_workspace_id)

        is_expected.to be_success
      end
    end

    context 'when build_user_map raises an unexpected error' do
      before do
        allow(ChatName).to receive(:for_team_and_chat_ids).and_raise(ActiveRecord::StatementInvalid, 'db error')
      end

      it 'tracks the exception and still succeeds' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(ActiveRecord::StatementInvalid), slack_workspace_id: slack_workspace_id)

        is_expected.to be_success
      end
    end

    context 'when thread has multiple messages with linked and unlinked users' do
      let(:other_user) { create(:user, username: 'other_dev') }
      let(:other_chat_name) do
        create(:chat_name, user: other_user, team_id: slack_installation.team_id, chat_id: 'U999OTHER')
      end

      let(:unlinked_user_id) { 'U_UNKNOWN' }
      let(:thread_replies_response) do
        {
          ok: true,
          messages: [
            { user: slack_user_id, text: 'Can someone help?', ts: '1234567890.000001' },
            { user: other_chat_name.chat_id, text: 'Sure!', ts: '1234567891.000001' },
            { user: unlinked_user_id, text: 'Me too', ts: '1234567892.000001' },
            { user: slack_user_id, text: event_text, ts: message_ts }
          ]
        }
      end

      it 'builds goal with participants and conversation sections', :aggregate_failures do
        captured_goal = nil

        expect(mock_adapter).to receive(:trigger) do |bundle|
          captured_goal = bundle.goal
          trigger_result
        end

        execute

        expect(captured_goal).to include('<participants>')
        expect(captured_goal).to include('</participants>')
        expect(captured_goal).to include("Slack: #{slack_user_id} | GitLab: @#{user.username}")
        expect(captured_goal).to include("Slack: #{other_chat_name.chat_id} | GitLab: @other_dev")
        expect(captured_goal).to include("Slack: #{unlinked_user_id}")
        expect(captured_goal).to exclude("#{unlinked_user_id} | GitLab:")
        expect(captured_goal).to include('<conversation>')
        expect(captured_goal).to include("<message author=\"#{slack_user_id}\" gitlab=\"@#{user.username}\">")
        expect(captured_goal).to include('Can someone help?')
        expect(captured_goal).to include("<message author=\"#{unlinked_user_id}\">")
        expect(captured_goal).to exclude("<message author=\"#{unlinked_user_id}\" gitlab=")
        expect(captured_goal).to include('standard Markdown')
      end
    end

    describe 'goal truncation' do
      let(:slack_goal_max) { EE::Integrations::SlackEvents::AppMentionedService::SLACK_GOAL_MAX }

      context 'when the thread is small enough to fit within SLACK_GOAL_MAX' do
        it 'returns the goal unchanged (no truncation)', :aggregate_failures do
          captured_goal = nil

          expect(mock_adapter).to receive(:trigger) do |bundle|
            captured_goal = bundle.goal
            trigger_result
          end

          execute

          expect(captured_goal.length).to be <= slack_goal_max
          expect(captured_goal).to include('<conversation>')
        end
      end

      context 'when the thread would produce a goal exceeding SLACK_GOAL_MAX' do
        # Each message is ~6000 chars; three of them plus overhead will exceed 16000.
        let(:big_text) { 'y' * 6000 }
        let(:thread_replies_response) do
          {
            ok: true,
            messages: [
              { user: slack_user_id, text: "oldest #{big_text}", ts: '1000.000001' },
              { user: 'U_OTHER', text: big_text, ts: '1000.000002' },
              { user: 'U_OTHER', text: big_text, ts: '1000.000003' },
              { user: slack_user_id, text: "newest ask #{big_text}", ts: '1000.000004' }
            ]
          }
        end

        it 'truncates newest-first within budget, dropping the oldest with an omission marker', :aggregate_failures do
          captured_goal = nil

          expect(mock_adapter).to receive(:trigger) do |bundle|
            captured_goal = bundle.goal
            trigger_result
          end

          execute

          expect(captured_goal.length).to be <= slack_goal_max
          # Newest-first: the triggering message is kept, the oldest is dropped.
          expect(captured_goal).to include('newest ask')
          expect(captured_goal).to exclude('oldest')
          # An omission marker (XML comment) flags the dropped messages.
          expect(captured_goal).to include('omitted due to length')
          expect(captured_goal).to include('<!--')
        end
      end

      context 'when the triggering message alone exceeds the budget' do
        let(:huge_text) { 'z' * 20_000 }
        let(:thread_replies_response) do
          {
            ok: true,
            messages: [
              { user: slack_user_id, text: huge_text, ts: '1000.000001' }
            ]
          }
        end

        it 'does not trigger the flow and delivers a :message_too_long error', :aggregate_failures do
          expect(mock_adapter).not_to receive(:trigger)
          expect(mock_adapter).to receive(:deliver_error).with(
            callback_context: anything,
            error: :message_too_long
          )

          execute

          expect(WebMock).to have_requested(:post, reactions_add_url)
            .with(body: hash_including('name' => 'x'))
        end
      end
    end
  end
end
