# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::Adapters::Slack, feature_category: :duo_agent_platform do
  let_it_be(:slack_installation) { create(:slack_integration) }

  let(:team_id) { slack_installation.team_id }
  let(:channel_id) { 'C0123ABC' }
  let(:thread_ts) { '1234567890.123456' }
  let(:message_ts) { '1234567890.123456' }
  let(:user_id) { 'U0123ABC' }

  let(:callback_context) do
    {
      'adapter' => 'slack',
      'team_id' => team_id,
      'channel_id' => channel_id,
      'thread_ts' => thread_ts,
      'message_ts' => message_ts,
      'user_id' => user_id
    }
  end

  let(:reactions_add_url) { "#{Slack::API::BASE_URL}/reactions.add" }
  let(:reactions_remove_url) { "#{Slack::API::BASE_URL}/reactions.remove" }
  let(:post_message_url) { "#{Slack::API::BASE_URL}/chat.postMessage" }
  let(:update_message_url) { "#{Slack::API::BASE_URL}/chat.update" }
  let(:set_status_url) { "#{Slack::API::BASE_URL}/assistant.threads.setStatus" }
  let(:post_ephemeral_url) { "#{Slack::API::BASE_URL}/chat.postEphemeral" }

  subject(:adapter) do
    described_class.new(
      team_id: team_id,
      channel_id: channel_id,
      thread_ts: thread_ts,
      message_ts: message_ts,
      user_id: user_id
    )
  end

  before do
    stub_request(:post, reactions_add_url).to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, reactions_remove_url).to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, post_message_url).to_return(
      status: 200, body: { ok: true, ts: '111.222' }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, update_message_url).to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, set_status_url).to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, post_ephemeral_url).to_return(
      status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
  end

  describe '.adapter_key' do
    it { expect(described_class.adapter_key).to eq('slack') }
  end

  describe '.supports_live_progress?' do
    it { expect(described_class.supports_live_progress?).to be(true) }
  end

  describe '.from_callback_context' do
    it 'reconstructs an adapter from callback context' do
      restored = described_class.from_callback_context(callback_context)

      expect(restored).to be_a(described_class)
      expect(restored.build_callback_context).to eq(
        'team_id' => team_id,
        'channel_id' => channel_id,
        'thread_ts' => thread_ts,
        'message_ts' => message_ts,
        'user_id' => user_id
      )
    end
  end

  describe '#build_callback_context' do
    it 'returns Slack delivery coordinates' do
      expect(adapter.build_callback_context).to eq(
        'team_id' => team_id,
        'channel_id' => channel_id,
        'thread_ts' => thread_ts,
        'message_ts' => message_ts,
        'user_id' => user_id
      )
    end
  end

  describe '#on_request_received' do
    it 'adds eyes reaction to the mention message' do
      adapter.on_request_received

      expect(WebMock).to have_requested(:post, reactions_add_url).with(
        body: hash_including(
          'name' => 'eyes',
          'channel' => channel_id,
          'timestamp' => message_ts
        )
      )
    end

    it 'sets a rotating thinking status via assistant.threads.setStatus' do
      adapter.on_request_received

      expect(WebMock).to have_requested(:post, set_status_url).with { |req|
        body = ::Gitlab::Json.safe_parse(req.body)
        body['channel_id'] == channel_id &&
          body['thread_ts'] == thread_ts &&
          body['loading_messages'].is_a?(Array) &&
          body['loading_messages'].length > 1
      }
    end

    it 'does not post a message (the status indicator is sufficient)' do
      adapter.on_request_received

      expect(WebMock).not_to have_requested(:post, post_message_url)
    end

    it 'does not stash a status_ts (no message was posted)' do
      adapter.on_request_received

      expect(adapter.build_callback_context).not_to include('status_ts')
    end
  end

  describe '#on_flow_started' do
    let(:workflow) { create(:duo_workflows_workflow) }

    it 'records the session url and persists it without posting a message', :aggregate_failures do
      allow(workflow).to receive(:web_url).and_return('https://gl.test/s/1')

      adapter.on_flow_started(callback_context: callback_context, workflow: workflow)

      expect(WebMock).not_to have_requested(:post, post_message_url)
      expect(workflow.reload.messaging_callback_context).to include('session_url' => 'https://gl.test/s/1')
    end

    it 'persists the workflow id for the feedback buttons' do
      adapter.on_flow_started(callback_context: callback_context, workflow: workflow)

      expect(workflow.reload.messaging_callback_context).to include('workflow_id' => workflow.id)
    end

    it 'omits session_url when the workflow has no session page to link' do
      allow(workflow).to receive(:web_url).and_return(nil)

      adapter.on_flow_started(callback_context: callback_context, workflow: workflow)

      expect(workflow.reload.messaging_callback_context).not_to include('session_url')
    end
  end

  describe '#on_flow_completed' do
    it 'removes eyes and adds checkmark reaction', :aggregate_failures do
      adapter.on_flow_completed(callback_context: callback_context, workflow: double)

      expect(WebMock).to have_requested(:post, reactions_remove_url).with(
        body: hash_including('name' => 'eyes')
      )
      expect(WebMock).to have_requested(:post, reactions_add_url).with(
        body: hash_including('name' => 'white_check_mark')
      )
    end
  end

  describe '#on_flow_failed' do
    shared_examples 'clears the working reaction and marks failure' do
      it 'removes the eyes reaction and adds the x reaction', :aggregate_failures do
        action

        expect(WebMock).to have_requested(:post, reactions_remove_url).with(
          body: hash_including('name' => 'eyes')
        )
        expect(WebMock).to have_requested(:post, reactions_add_url).with(
          body: hash_including('name' => 'x')
        )
      end
    end

    context 'when workflow is present but no message was posted (failure before start)' do
      let(:workflow) { instance_double(Ai::DuoWorkflows::Workflow, web_url: 'https://gl.test/s/1') }

      subject(:action) do
        adapter.on_flow_failed(
          callback_context: callback_context,
          error: :flow_failed,
          workflow: workflow
        )
      end

      include_examples 'clears the working reaction and marks failure'

      it 'posts a threaded reply with the error and a context-block session link', :aggregate_failures do
        action

        expect(WebMock).to have_requested(:post, post_message_url)
          .with { |req| req.body.include?('went wrong') && req.body.include?('View session in GitLab') }
        expect(WebMock).to have_requested(:post, post_message_url)
          .with { |req| req.body.include?('context') && req.body.include?('https://gl.test/s/1') }
        expect(WebMock).not_to have_requested(:post, post_ephemeral_url)
      end
    end

    context 'when workflow is nil (sync failure)' do
      subject(:action) do
        adapter.on_flow_failed(
          callback_context: callback_context,
          error: :service_account_error,
          workflow: nil
        )
      end

      include_examples 'clears the working reaction and marks failure'

      it 'delivers an ephemeral error message' do
        action

        expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
          body: hash_including('text' => a_string_including('service account'))
        )
      end
    end

    context 'when a status message exists' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }

      subject(:action) do
        adapter.on_flow_failed(callback_context: callback_context, error: :flow_failed, workflow: double)
      end

      include_examples 'clears the working reaction and marks failure'

      it 'edits the message with the error text instead of an ephemeral', :aggregate_failures do
        action

        expect(WebMock).to have_requested(:post, update_message_url).with(
          body: hash_including('ts' => '111.222', 'text' => a_string_including('went wrong'))
        )
        expect(WebMock).not_to have_requested(:post, post_ephemeral_url)
        # status was cleared by posting the message; do not clear it again
        expect(WebMock).not_to have_requested(:post, set_status_url)
      end

      context 'with a session_url' do
        let(:callback_context) { super().merge('session_url' => 'https://gl.test/s/1') }

        it 'keeps the session link footer in the error message' do
          action

          expect(WebMock).to have_requested(:post, update_message_url)
            .with { |req| req.body.include?('View session in GitLab') }
        end
      end
    end
  end

  describe '#on_progress' do
    let(:delta_messages) { [] }
    let(:delta) { instance_double(Ai::DuoWorkflows::ProgressReader::Delta, messages: delta_messages) }

    def todo_message(todos)
      { 'message_type' => 'tool', 'tool_info' => { 'name' => 'todo_write', 'args' => { 'todos' => todos } } }
    end

    def agent_message(content)
      { 'message_type' => 'agent', 'content' => content }
    end

    def blocks_in(req)
      ::Gitlab::Json.safe_parse(req.body)['blocks']
    end

    def plan_in(req)
      blocks_in(req).find { |b| b['type'] == 'plan' }
    end

    context 'when the delta contains a todo_write tool call and a status_ts is present' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:todos) do
        [
          { 'status' => 'completed', 'description' => 'Read the codebase' },
          { 'status' => 'in_progress', 'description' => 'Write the tests' },
          { 'status' => 'pending', 'description' => 'Open a merge request' }
        ]
      end

      let(:delta_messages) { [todo_message(todos)] }

      it 'edits the ack message with a single plan block listing every todo', :aggregate_failures do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          body = ::Gitlab::Json.safe_parse(req.body)
          plan = body['blocks'].find { |b| b['type'] == 'plan' }
          body['ts'] == '111.222' &&
            plan.present? &&
            plan['tasks'].map { |t| t['status'] } == %w[complete in_progress pending]
        }
      end

      it 'includes pending todos as tasks (the whole plan is shown up front)' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          plan_in(req)['tasks'].map { |t| t['title'] } ==
            ['Read the codebase', 'Write the tests', 'Open a merge request']
        }
      end

      it 'does not render any task_card blocks (uses a single plan block)' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          blocks_in(req).none? { |b| b['type'] == 'task_card' }
        }
      end

      context 'when a todo has cancelled status' do
        let(:todos) { [{ 'status' => 'cancelled', 'description' => 'Cancelled task' }] }

        it 'maps cancelled to complete (Slack has no cancelled state)' do
          adapter.on_progress(delta: delta, callback_context: callback_context)

          expect(WebMock).to have_requested(:post, update_message_url).with { |req|
            plan_in(req)['tasks'].first['status'] == 'complete'
          }
        end
      end

      context 'when a todo has an unrecognised status' do
        let(:todos) { [{ 'status' => 'complete', 'description' => 'Rogue task' }] }

        it 'tracks the KeyError and does not update the message' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(KeyError),
            hash_including(slack_team_id: team_id)
          )

          adapter.on_progress(delta: delta, callback_context: callback_context)

          expect(WebMock).not_to have_requested(:post, update_message_url)
        end
      end

      it 'assigns positional task_ids to each task' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          plan_in(req)['tasks'].map { |t| t['task_id'] } == %w[task_0 task_1 task_2]
        }
      end

      it 'gives the plan a fresh block_id' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          plan_in(req)['block_id'].present?
        }
      end

      it 'uses todo descriptions joined by newlines as the plain-text fallback' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          ::Gitlab::Json.safe_parse(req.body)['text'] == "Read the codebase\nWrite the tests\nOpen a merge request"
        }
      end

      context 'with an agent monologue' do
        let(:delta_messages) { [todo_message(todos), agent_message('Writing the spec file now')] }

        it 'renders the latest reasoning as a markdown block after the plan', :aggregate_failures do
          adapter.on_progress(delta: delta, callback_context: callback_context)

          expect(WebMock).to have_requested(:post, update_message_url).with { |req|
            blocks = blocks_in(req)
            plan_idx = blocks.index { |b| b['type'] == 'plan' }
            md = blocks.find { |b| b['type'] == 'markdown' }
            md_idx = blocks.index { |b| b['type'] == 'markdown' }
            plan_idx && md_idx && md_idx > plan_idx && md['text'].include?('Writing the spec file now')
          }
        end

        context 'when the monologue is very long' do
          let(:delta_messages) { [todo_message(todos), agent_message("#{'word ' * 400}end")] }

          it 'truncates it to MONOLOGUE_MAX_LENGTH' do
            adapter.on_progress(delta: delta, callback_context: callback_context)

            expect(WebMock).to have_requested(:post, update_message_url).with { |req|
              md = blocks_in(req).find { |b| b['type'] == 'markdown' }
              md['text'].length <= described_class::MONOLOGUE_MAX_LENGTH
            }
          end
        end
      end

      context 'with a session_url' do
        let(:callback_context) { super().merge('session_url' => 'https://gl.test/s/1') }

        it 'appends a context-block footer with the session link after the plan' do
          adapter.on_progress(delta: delta, callback_context: callback_context)

          expect(WebMock).to have_requested(:post, update_message_url).with { |req|
            blocks = blocks_in(req)
            blocks.any? { |b| b['type'] == 'plan' } &&
              blocks.any? { |b| b['type'] == 'context' && b.to_s.include?('View session in GitLab') }
          }
        end
      end

      context 'when multiple todo_write messages are present' do
        let(:older_todos) { [{ 'status' => 'pending', 'description' => 'Old task' }] }
        let(:newer_todos) { [{ 'status' => 'in_progress', 'description' => 'New task' }] }
        let(:delta_messages) { [todo_message(older_todos), todo_message(newer_todos)] }

        it 'renders only the latest todo_write entry' do
          adapter.on_progress(delta: delta, callback_context: callback_context)

          expect(WebMock).to have_requested(:post, update_message_url).with { |req|
            body = req.body
            body.include?('New task') && body.exclude?('Old task')
          }
        end
      end
    end

    context 'when no status_ts is present yet (first real content)' do
      let(:todos) { [{ 'status' => 'pending', 'description' => 'Do something' }] }
      let(:delta_messages) { [todo_message(todos)] }

      it 'posts a new message (the status indicator clears automatically)' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, post_message_url).with { |req|
          body = ::Gitlab::Json.safe_parse(req.body)
          body['thread_ts'] == thread_ts && body['blocks'].any? { |b| b['type'] == 'plan' }
        }
      end

      it 'stashes the posted message ts in callback_context' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(callback_context['status_ts']).to eq('111.222')
      end
    end

    context 'when the delta has no todo_write but the agent is reasoning (short task)' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:delta_messages) { [agent_message('Looking into it')] }

      it 'renders just the reasoning markdown, with no plan block', :aggregate_failures do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).to have_requested(:post, update_message_url).with { |req|
          blocks = blocks_in(req)
          blocks.none? { |b| b['type'] == 'plan' } &&
            blocks.any? { |b| b['type'] == 'markdown' && b['text'].include?('Looking into it') }
        }
      end
    end

    context 'when the todo_write entry has an empty todos array and no reasoning' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:empty_todo_tool_info) { { 'name' => 'todo_write', 'args' => { 'todos' => [] } } }
      let(:delta_messages) { [{ 'message_type' => 'tool', 'tool_info' => empty_todo_tool_info }] }

      it 'does not update the acknowledgement message' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).not_to have_requested(:post, update_message_url)
      end
    end

    context 'when the delta has only an unrelated tool call' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:delta_messages) { [{ 'message_type' => 'tool', 'tool_info' => { 'name' => 'run_command' } }] }

      it 'does not update the acknowledgement message' do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).not_to have_requested(:post, update_message_url)
      end
    end

    context 'when the delta is empty' do
      let(:delta_messages) { [] }

      it 'makes no Slack API calls', :aggregate_failures do
        adapter.on_progress(delta: delta, callback_context: callback_context)

        expect(WebMock).not_to have_requested(:post, update_message_url)
        expect(WebMock).not_to have_requested(:post, set_status_url)
      end
    end

    context 'when a Slack API error occurs' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:todos) { [{ 'status' => 'pending', 'description' => 'Do something' }] }
      let(:delta_messages) { [todo_message(todos)] }

      before do
        stub_request(:post, update_message_url).to_raise(StandardError.new('network error'))
      end

      it 'tracks the exception and does not raise' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          hash_including(slack_team_id: team_id)
        )

        expect { adapter.on_progress(delta: delta, callback_context: callback_context) }.not_to raise_error
      end
    end
  end

  describe '#deliver_result' do
    # By default the run had no todo list: the latest checkpoint has an empty
    # ui_chat_log, so final_todos is empty and no plan block is rendered.
    let(:workflow) { build_stubbed(:duo_workflows_workflow) }

    before do
      allow(workflow).to receive(:latest_ui_chat_log).and_return([])
    end

    shared_examples 'the final result content' do
      it 'renders the answer in a markdown block' do
        adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

        expect(WebMock).to have_requested(:post, delivery_url).with { |req|
          ::Gitlab::Json.safe_parse(req.body)['blocks']
            .any? { |b| b['type'] == 'markdown' && b['text'] == 'Done!' }
        }
      end

      context 'with a session_url' do
        let(:callback_context) { super().merge('session_url' => 'https://gl.test/s/1') }

        it 'links the session in a footer block and in the notification text', :aggregate_failures do
          adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

          expect(WebMock).to have_requested(:post, delivery_url).with { |req|
            ::Gitlab::Json.safe_parse(req.body)['blocks'].any? do |b|
              b['type'] == 'context' && b.to_s.include?('View session in GitLab')
            end
          }
          expect(WebMock).to have_requested(:post, delivery_url).with(
            body: hash_including('text' => a_string_including('Done!', 'View session in GitLab'))
          )
        end
      end

      context 'when the run had a todo list' do
        let(:todos) { [{ 'status' => 'completed', 'description' => 'Do the thing' }] }

        before do
          allow(workflow).to receive(:latest_ui_chat_log).and_return(
            [{ 'tool_info' => { 'name' => 'todo_write', 'args' => { 'todos' => todos } } }]
          )
        end

        it 'prepends the plan block before the final answer so users can inspect the task list' do
          adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

          expect(WebMock).to have_requested(:post, delivery_url).with { |req|
            blocks = ::Gitlab::Json.safe_parse(req.body)['blocks']
            plan_idx = blocks.index { |b| b['type'] == 'plan' }
            md_idx = blocks.index { |b| b['type'] == 'markdown' }
            plan_idx && md_idx && plan_idx < md_idx
          }
        end

        it 'renders the plan from the terminal checkpoint so completed tasks are not shown as in_progress' do
          # Regression: the final todo_write (all complete) lands in the terminal
          # checkpoint after live progress stops. Reading it here keeps the plan
          # in sync with the final answer instead of freezing a stale render.
          adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

          expect(WebMock).to have_requested(:post, delivery_url).with { |req|
            plan = ::Gitlab::Json.safe_parse(req.body)['blocks'].find { |b| b['type'] == 'plan' }
            plan['tasks'].map { |t| t['status'] } == ['complete']
          }
        end
      end

      context 'with a workflow_id' do
        let(:callback_context) { super().merge('workflow_id' => 42) }

        it 'appends a feedback_buttons block with the workflow id packed into the values' do
          adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

          expect(WebMock).to have_requested(:post, delivery_url).with { |req|
            blocks = ::Gitlab::Json.safe_parse(req.body)['blocks']
            feedback = blocks.find { |b| b['type'] == 'context_actions' }&.dig('elements', 0)

            feedback && feedback['type'] == 'feedback_buttons' &&
              feedback['action_id'] == 'duo_feedback' &&
              feedback['positive_button']['value'] == 'up:42' &&
              feedback['negative_button']['value'] == 'down:42'
          }
        end
      end

      it 'omits the feedback block when there is no workflow_id' do
        adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

        expect(WebMock).to have_requested(:post, delivery_url)
          .with { |req| req.body.exclude?('feedback_buttons') }
      end
    end

    context 'when on_progress never posted a message' do
      let(:delivery_url) { post_message_url }

      it_behaves_like 'the final result content'

      it 'posts the answer as a new threaded reply', :aggregate_failures do
        adapter.deliver_result(callback_context: callback_context, message: 'Hello from Duo!', workflow: workflow)

        expect(WebMock).to have_requested(:post, post_message_url).with(
          body: hash_including('channel' => channel_id, 'thread_ts' => thread_ts, 'text' => 'Hello from Duo!')
        )
        expect(WebMock).not_to have_requested(:post, update_message_url)
      end

      it 'returns true once Slack accepted the reply' do
        expect(adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow))
          .to be(true)
      end

      context 'when Slack rejects the post' do
        before do
          stub_request(:post, post_message_url).to_return(
            status: 200, body: { ok: false, error: 'channel_not_found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        end

        it 'returns false so the caller can retry the delivery' do
          expect(adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow))
            .to be(false)
        end
      end
    end

    context 'when on_progress already posted a progress message' do
      let(:callback_context) { super().merge('status_ts' => '111.222') }
      let(:delivery_url) { update_message_url }

      it_behaves_like 'the final result content'

      it 'edits that message in place instead of posting a new one', :aggregate_failures do
        adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

        expect(WebMock).to have_requested(:post, update_message_url).with(
          body: hash_including('ts' => '111.222')
        )
        expect(WebMock).not_to have_requested(:post, post_message_url)
      end

      context 'when the block render is rejected' do
        before do
          # First call (with blocks) is rejected; second call (blocks: []) succeeds.
          stub_request(:post, update_message_url).to_return(
            { status: 200, body: { ok: false, error: 'invalid_blocks' }.to_json,
              headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' } }
          )
        end

        it 'retries with a plain-text edit clearing blocks so the answer is not lost', :aggregate_failures do
          adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow)

          expect(WebMock).to have_requested(:post, update_message_url).twice
          expect(WebMock).to have_requested(:post, update_message_url)
            .with { |req| req.body.include?('"blocks":[]') }
        end

        it 'returns true because the plain-text retry landed' do
          expect(adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow))
            .to be(true)
        end
      end

      it 'returns true once Slack accepted the edit' do
        expect(adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow))
          .to be(true)
      end

      context 'when Slack rejects both the block edit and the plain-text retry' do
        before do
          stub_request(:post, update_message_url).to_return(
            status: 200, body: { ok: false, error: 'message_not_found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        end

        it 'returns false so the caller can retry the delivery' do
          expect(adapter.deliver_result(callback_context: callback_context, message: 'Done!', workflow: workflow))
            .to be(false)
        end
      end
    end
  end

  describe '#deliver_error' do
    it 'posts an ephemeral error message to the user' do
      adapter.deliver_error(callback_context: callback_context, error: :namespace_not_configured)

      expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
        body: hash_including(
          'channel' => channel_id,
          'user' => user_id,
          'text' => a_string_including('default Duo namespace')
        )
      )
    end

    it 'handles unknown errors with a generic message' do
      adapter.deliver_error(callback_context: callback_context, error: :something_unexpected)

      expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
        body: hash_including('text' => a_string_including('Something went wrong. Try again.'))
      )
    end

    context 'when the mention was inside an existing thread (thread_ts != message_ts)' do
      let(:thread_ts) { '1111111111.000001' }
      let(:message_ts) { '9999999999.000001' }

      it 'posts the ephemeral into the thread' do
        adapter.deliver_error(callback_context: callback_context, error: :flow_failed)

        expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
          body: hash_including('thread_ts' => thread_ts)
        )
      end
    end

    context 'when the mention was a top-level channel message (thread_ts == message_ts)' do
      let(:thread_ts) { '1234567890.123456' }
      let(:message_ts) { '1234567890.123456' }

      it 'posts the ephemeral at channel root (no thread_ts)' do
        adapter.deliver_error(callback_context: callback_context, error: :flow_failed)

        expect(WebMock).to have_requested(:post, post_ephemeral_url)
          .with { |req| req.body.exclude?('thread_ts') }
      end
    end

    context 'when thread_ts is absent from the callback context' do
      let(:callback_context) { super().except('thread_ts') }

      it 'posts the ephemeral at channel root (no thread_ts)' do
        adapter.deliver_error(callback_context: callback_context, error: :flow_failed)

        expect(WebMock).to have_requested(:post, post_ephemeral_url)
          .with { |req| req.body.exclude?('thread_ts') }
      end
    end
  end

  describe 'error text mapping' do
    using RSpec::Parameterized::TableSyntax

    where(:error_sym, :expected_text) do
      :namespace_not_configured | 'default Duo namespace'
      :flow_not_enabled         | 'not enabled for your namespace'
      :service_account_error    | 'service account for the Duo Developer flow'
      :workspace_project_error  | 'workspace project'
      :execute_workflow_failed  | 'Failed to start the Duo Developer workflow'
      :flow_failed              | 'went wrong while running'
      :no_response              | "didn't produce a response"
      :message_too_long         | 'Your message is too long'
    end

    with_them do
      it 'delivers the correct error text via ephemeral message' do
        adapter.on_flow_failed(callback_context: callback_context, error: error_sym)

        expect(WebMock).to have_requested(:post, post_ephemeral_url).with(
          body: hash_including('text' => a_string_including(expected_text))
        )
      end
    end
  end

  context 'when Slack installation is not found' do
    let(:nonexistent_adapter) do
      described_class.new(
        team_id: 'NONEXISTENT',
        channel_id: channel_id,
        thread_ts: thread_ts,
        message_ts: message_ts,
        user_id: user_id
      )
    end

    let(:nonexistent_context) { nonexistent_adapter.build_callback_context }

    it 'tracks exception on deliver_result instead of raising' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(described_class::InstallationNotFoundError),
        hash_including(slack_team_id: 'NONEXISTENT')
      )

      expect do
        nonexistent_adapter.deliver_result(
          callback_context: nonexistent_context, message: 'test', workflow: build_stubbed(:duo_workflows_workflow)
        )
      end.not_to raise_error
    end

    it 'returns false from deliver_result so the caller can retry the delivery' do
      allow(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(
        nonexistent_adapter.deliver_result(
          callback_context: nonexistent_context, message: 'test', workflow: build_stubbed(:duo_workflows_workflow)
        )
      ).to be(false)
    end

    it 'tracks exception on deliver_error instead of raising' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(described_class::InstallationNotFoundError),
        hash_including(slack_team_id: 'NONEXISTENT')
      )

      expect { nonexistent_adapter.deliver_error(callback_context: nonexistent_context, error: :flow_failed) }
        .not_to raise_error
    end

    it 'tracks exception on on_request_received instead of raising' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(described_class::InstallationNotFoundError),
        hash_including(slack_team_id: 'NONEXISTENT')
      )

      nonexistent_adapter.on_request_received
    end
  end

  describe 'Slack API caching' do
    let(:workflow) { build_stubbed(:duo_workflows_workflow) }

    it 'reuses the Slack API client for the same team' do
      expect(SlackIntegration).to receive(:with_bot).once.and_call_original

      adapter.deliver_result(callback_context: callback_context, message: 'first', workflow: workflow)
      adapter.deliver_result(callback_context: callback_context, message: 'second', workflow: workflow)
    end
  end

  describe 'Slack API error handling' do
    using RSpec::Parameterized::TableSyntax

    where(:api_method, :slack_error, :log_message) do
      'reactions.add'      | 'already_reacted'   | 'Slack API error when adding reaction'
      'reactions.remove'   | 'no_reaction'       | 'Slack API error when removing reaction'
      'chat.postMessage'   | 'channel_not_found' | 'Slack API error when posting message'
      'chat.postEphemeral' | 'user_not_found'    | 'Slack API error when posting ephemeral message'
    end

    with_them do
      before do
        stub_request(:post, "#{Slack::API::BASE_URL}/#{api_method}").to_return(
          status: 200, body: { ok: false, error: slack_error }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'logs the error and does not raise' do
        expect(Gitlab::IntegrationsLogger).to receive(:error).with(
          hash_including(message: log_message)
        )

        # Trigger the code path that exercises the stubbed API method
        case api_method
        when 'reactions.add'
          expect { adapter.on_request_received }.not_to raise_error
        when 'reactions.remove'
          expect { adapter.on_flow_completed(callback_context: callback_context, workflow: double) }
            .not_to raise_error
        when 'chat.postMessage'
          expect do
            adapter.deliver_result(
              callback_context: callback_context, message: 'test', workflow: build_stubbed(:duo_workflows_workflow)
            )
          end.not_to raise_error
        when 'chat.postEphemeral'
          expect { adapter.deliver_error(callback_context: callback_context, error: :flow_failed) }
            .not_to raise_error
        end
      end
    end
  end
end
