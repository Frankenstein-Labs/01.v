# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter, feature_category: :duo_agent_platform do
  let(:checkpoint) { build_stubbed(:duo_workflows_checkpoint) }
  let_it_be(:user) { build_stubbed(:user) }

  subject(:presenter) { described_class.new(checkpoint, current_user: user) }

  describe 'thread_ts' do
    it 'returns the checkpoint thread_ts' do
      expect(presenter.thread_ts).to eq(checkpoint.thread_ts)
    end
  end

  describe 'parent_ts' do
    it 'returns nil if the checkpoint has no parent ts' do
      checkpoint.parent_ts = nil
      expect(presenter.parent_ts).to be_nil
    end

    it 'returns the checkpoint parent_ts' do
      expect(presenter.parent_ts).to eq(checkpoint.parent_ts)
    end
  end

  describe 'metadata' do
    it 'returns the checkpoint metadata' do
      expect(presenter.metadata).to eq(checkpoint.metadata)
    end
  end

  describe 'checkpoint' do
    it 'returns the checkpoint' do
      expect(presenter.checkpoint).to eq(checkpoint.checkpoint)
    end
  end

  describe 'workflow_status' do
    it 'returns the workflow status' do
      expect(presenter.workflow_status).to eq(checkpoint.workflow.status)
    end
  end

  describe 'execution_status' do
    context 'when checkpoint channel values is empty' do
      it 'returns the workflow status' do
        expect(presenter.execution_status).to eq(checkpoint.workflow.human_status_name.titleize)
      end
    end

    context 'when graph execution has started' do
      let(:checkpoint_data) do
        {
          'channel_values' =>
            {
              'plan' => { 'steps' => [] },
              'status' => 'Planning',
              'handover' => [],
              'ui_chat_log' => [],
              'last_human_input' => nil,
              'conversation_history' => {}
            }
        }
      end

      before do
        checkpoint.checkpoint = checkpoint_data
      end

      it 'returns the graph execution status' do
        expect(presenter.execution_status).to eq('Planning')
      end
    end

    context 'when graph execution has not started' do
      let(:checkpoint_data) do
        {
          'channel_values' =>
            {
              'plan' => { 'steps' => [] },
              'status' => 'Not Started',
              'handover' => [],
              'ui_chat_log' => [],
              'last_human_input' => nil,
              'conversation_history' => {}
            }
        }
      end

      before do
        checkpoint.checkpoint = checkpoint_data
      end

      it 'returns the workflow status' do
        expect(presenter.execution_status).to eq(checkpoint.workflow.human_status_name.titleize)
      end
    end
  end

  describe 'duo_messages' do
    let(:checkpoint_data) do
      {
        'channel_values' =>
          {
            'ui_chat_log' => ui_chat_log
          }
      }
    end

    before do
      checkpoint.checkpoint = checkpoint_data
    end

    context 'when all supported fields are present' do
      let(:ui_chat_log) do
        [
          {
            'content' => 'Delegating task',
            'message_type' => 'system',
            'status' => 'in_progress',
            'tool_info' => { 'tool_name' => 'todo_write' },
            'timestamp' => '2026-01-01T00:00:00Z',
            'correlation_id' => 'abc-123',
            'role' => 'assistant',
            'message_sub_type' => 'delegation',
            'component_name' => 'duo_developer',
            'subsession_id' => 'session-1'
          }
        ]
      end

      it 'passes through new fields' do
        message = presenter.duo_messages.first

        expect(message.message_sub_type).to eq('delegation')
        expect(message.component_name).to eq('duo_developer')
        expect(message.subsession_id).to eq('session-1')
      end

      it 'preserves existing fields' do
        message = presenter.duo_messages.first

        expect(message.content).to eq('Delegating task')
        expect(message.message_type).to eq('system')
        expect(message.status).to eq('in_progress')
        expect(message.tool_info).to eq({ 'tool_name' => 'todo_write' })
        expect(message.timestamp).to eq('2026-01-01T00:00:00Z')
        expect(message.correlation_id).to eq('abc-123')
        expect(message.role).to eq('assistant')
      end
    end

    context 'when new fields are missing' do
      let(:ui_chat_log) do
        [
          {
            'content' => 'Legacy message',
            'message_type' => 'request',
            'status' => 'done',
            'tool_info' => nil,
            'timestamp' => '2026-01-01T00:00:00Z',
            'correlation_id' => 'legacy-1',
            'role' => 'user'
          }
        ]
      end

      it 'defaults new fields to nil' do
        message = presenter.duo_messages.first

        expect(message.message_sub_type).to be_nil
        expect(message.component_name).to be_nil
        expect(message.subsession_id).to be_nil
      end

      it 'has no message lineage, since the header holds none to attribute' do
        message = presenter.duo_messages.first

        expect(message.thread_ts).to be_nil
        expect(message.parent_ts).to be_nil
        expect(message.alternative_count).to be_nil
      end
    end
  end

  describe 'workflow_goal' do
    it 'returns the workflow goal' do
      expect(presenter.workflow_goal).to eq(checkpoint.workflow.goal)
    end
  end

  describe 'workflow_definition' do
    it 'returns the workflow definition' do
      expect(presenter.workflow_definition).to eq(checkpoint.workflow.workflow_definition)
    end
  end

  describe '#duo_messages' do
    let(:checkpoint_data) do
      {
        'channel_values' => {
          'ui_chat_log' => [
            {
              'content' => 'hi',
              'message_type' => 'user',
              'message_sub_type' => 'start_flow',
              'status' => 'success',
              'tool_info' => nil,
              'timestamp' => '2025-11-25T21:10:57.734182+00:00',
              'correlation_id' => 'corr-123',
              'role' => nil,
              'message_id' => 'msg-123',
              'additional_context' => [{ 'id' => 'context-item-1', 'type' => 'file' }]
            }
          ]
        }
      }
    end

    before do
      checkpoint.checkpoint = checkpoint_data
    end

    it 'extracts message_id, message_sub_type, and additional_context from the checkpoint chat log',
      :aggregate_failures do
      message = presenter.duo_messages.first

      expect(message.message_id).to eq('msg-123')
      expect(message.message_sub_type).to eq('start_flow')
      expect(message.additional_context).to match_array([{ 'id' => 'context-item-1', 'type' => 'file' }])
    end

    context 'when additional_context contains internal orbit_context items' do
      let(:checkpoint_data) do
        {
          'channel_values' => {
            'ui_chat_log' => [
              {
                'content' => 'hi',
                'message_type' => 'user',
                'message_id' => 'msg-123',
                'additional_context' => [
                  { 'category' => 'orbit_context', 'content' => '{"orbit_enabled":true}', 'metadata' => '{}' },
                  { 'id' => 'context-item-1', 'category' => 'repository', 'content' => 'page' }
                ]
              }
            ]
          }
        }
      end

      it 'strips orbit_context items to prevent GraphQL enum serialization errors' do
        message = presenter.duo_messages.first

        expect(message.additional_context).to match_array(
          [{ 'id' => 'context-item-1', 'category' => 'repository', 'content' => 'page' }]
        )
      end
    end

    context 'when additional_context contains internal permissions_form_context items' do
      let(:checkpoint_data) do
        {
          'channel_values' => {
            'ui_chat_log' => [
              {
                'content' => 'hi',
                'message_type' => 'user',
                'message_id' => 'msg-123',
                'additional_context' => [
                  {
                    'category' => 'permissions_form_context',
                    'content' => '{"namespace":[],"user":[],"instance":[],"access":""}',
                    'metadata' => '{}'
                  },
                  { 'id' => 'context-item-1', 'category' => 'repository', 'content' => 'page' }
                ]
              }
            ]
          }
        }
      end

      it 'strips permissions_form_context items to prevent GraphQL enum serialization errors' do
        message = presenter.duo_messages.first

        expect(message.additional_context).to match_array(
          [{ 'id' => 'context-item-1', 'category' => 'repository', 'content' => 'page' }]
        )
      end
    end
  end

  # Persisted records are required: reconstruction runs a real query over the
  # checkpoint blobs (Workflow#history_blobs_for), so build_stubbed won't do.
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- see above
  describe 'duo_messages reconstructed from incremental checkpoint blobs' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be_with_refind(:workflow) do
      create(:duo_workflows_workflow, project: project, incremental_checkpoints_enabled: true)
    end

    # Header carries only scalar channels; ui_chat_log lives in the blobs.
    let(:checkpoint) do
      create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1', current_thread: 0,
        checkpoint: { 'channel_values' => { 'status' => 'Planning' } })
    end

    subject(:presenter) { described_class.new(checkpoint, current_user: user) }

    # Mirror the gateway wire format: data is zlib-compressed JSON.
    def blob(version:, value:, step_action: 'conversation', thread_ts: 'ts-1')
      create(:duo_workflows_checkpoint_blob,
        workflow: workflow, thread_ts: thread_ts, current_thread: 0, channel: 'ui_chat_log',
        version: version, step_action: step_action, data: Zlib::Deflate.deflate(Gitlab::Json.dump(value)))
    end

    # CreateCheckpointService writes a header alongside every checkpoint; the blob
    # read walks headers (Workflow#full_ancestor_thread_ts) to resolve the chain.
    def header(thread_ts: 'ts-1', parent_ts: nil)
      create(:duo_workflows_checkpoint_header,
        workflow: workflow, thread_ts: thread_ts, parent_ts: parent_ts, current_thread: 0)
    end

    before do
      stub_feature_flags(duo_workflow_read_incremental_checkpoints: project, dw_read_blobs_graphql: project)
    end

    it 'folds the ui_chat_log deltas from the blobs in version order' do
      header
      blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
      blob(version: '2', value: [{ 'content' => 'second', 'message_type' => 'agent' }])

      messages = presenter.duo_messages

      expect(messages.map(&:content)).to eq(%w[first second])
      expect(messages.map(&:message_type)).to eq(%w[user agent])
    end

    it 'exposes the checkpoint each message came from and the point to fork it at' do
      header
      header(thread_ts: 'ts-2', parent_ts: 'ts-1')
      blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
      blob(version: '2', thread_ts: 'ts-2', value: [{ 'content' => 'second', 'message_type' => 'agent' }])
      checkpoint_2 = create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-2', current_thread: 0)

      messages = described_class.new(checkpoint_2, current_user: user).duo_messages

      expect(messages.map { |message| [message.content, message.thread_ts, message.parent_ts] })
        .to eq([['first', 'ts-1', nil], %w[second ts-2 ts-1]])
    end

    it 'counts the alternatives of a retried turn on its user message' do
      header
      header(thread_ts: 'ts-abandoned', parent_ts: 'ts-1')
      header(thread_ts: 'ts-2', parent_ts: 'ts-1')
      blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
      blob(version: '2', thread_ts: 'ts-abandoned',
        value: [{ 'content' => 'abandoned', 'message_type' => 'user' }])
      blob(version: '2', thread_ts: 'ts-2', value: [{ 'content' => 'retried', 'message_type' => 'user' }])
      checkpoint_2 = create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-2', current_thread: 0)

      messages = described_class.new(checkpoint_2, current_user: user).duo_messages

      expect(messages.map { |message| [message.content, message.alternative_count] })
        .to eq([['first', 0], ['retried', 1]])
    end

    it 'spans a compaction, showing the full conversation and dropping the summary' do
      header
      create(:duo_workflows_checkpoint_header,
        workflow: workflow, thread_ts: 'ts-2', parent_ts: 'ts-1', current_thread: 1)
      blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
      blob(version: '2', value: [{ 'content' => 'second', 'message_type' => 'agent' }])
      create(:duo_workflows_checkpoint_blob,
        workflow: workflow, thread_ts: 'ts-2', current_thread: 1, channel: 'ui_chat_log',
        version: '3', step_action: 'compaction',
        data: Zlib::Deflate.deflate(Gitlab::Json.dump([{ 'content' => 'summary' }])))
      create(:duo_workflows_checkpoint_blob,
        workflow: workflow, thread_ts: 'ts-2', current_thread: 1, channel: 'ui_chat_log',
        version: '4', step_action: 'conversation',
        data: Zlib::Deflate.deflate(Gitlab::Json.dump([{ 'content' => 'third', 'message_type' => 'user' }])))
      group_1_checkpoint = create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-2',
        current_thread: 1, checkpoint: { 'channel_values' => { 'status' => 'Planning' } })

      messages = described_class.new(group_1_checkpoint, current_user: user).duo_messages

      expect(messages.map(&:content)).to eq(%w[first second third])
    end

    describe '#last_duo_message' do
      it 'returns the tail of the newest ui_chat_log blob without folding the channel' do
        header
        blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
        blob(version: '2',
          value: [{ 'content' => 'second', 'message_type' => 'agent' },
            { 'content' => 'third', 'message_type' => 'agent' }])

        expect(workflow).not_to receive(:channel_message_history)

        expect(presenter.last_duo_message.content).to eq('third')
      end

      it 'returns nil when there are no messages' do
        expect(presenter.last_duo_message).to be_nil
      end
    end

    describe '#checkpoint' do
      it 'overlays the reconstructed channel_values onto the raw header', :aggregate_failures do
        header
        blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])
        blob(version: '2', value: [{ 'content' => 'second', 'message_type' => 'agent' }])

        channel_values = presenter.checkpoint['channel_values']

        expect(channel_values['status']).to eq('Planning')
        expect(channel_values['ui_chat_log'].map { |m| m['content'] }).to eq(%w[first second])
      end

      context 'when the graphql consumer flag is off' do
        before do
          stub_feature_flags(dw_read_blobs_graphql: false)
        end

        it 'returns the raw header verbatim and ignores the blobs' do
          header
          blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])

          expect(presenter.checkpoint).to eq(checkpoint.checkpoint)
        end
      end
    end

    context 'when the read flag is off' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: false)
      end

      it 'reads the checkpoint header and ignores the blobs' do
        blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])

        expect(presenter.duo_messages).to eq([])
      end
    end

    context 'when the kill switch is on but the graphql consumer flag is off' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: project, dw_read_blobs_graphql: false)
      end

      it 'reads the checkpoint header and ignores the blobs' do
        blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])

        expect(presenter.duo_messages).to eq([])
      end
    end

    context 'when the workflow was not created with incremental checkpoints' do
      let(:workflow) do
        create(:duo_workflows_workflow, project: project, incremental_checkpoints_enabled: false)
      end

      it 'reads the checkpoint header and ignores the blobs' do
        blob(version: '1', value: [{ 'content' => 'first', 'message_type' => 'user' }])

        expect(presenter.duo_messages).to eq([])
      end
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  # status is a scalar (replace) channel, so folding its blobs returns the latest
  # value rather than concatenating. See ChannelValuesReconstructor#apply.
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- reconstruction runs a real query over the blobs
  describe 'execution_status reconstructed from incremental checkpoint blobs' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be_with_refind(:workflow) do
      create(:duo_workflows_workflow, project: project, incremental_checkpoints_enabled: true)
    end

    # Header still embeds an older status; the blobs carry the current one.
    let(:checkpoint) do
      create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1', current_thread: 0,
        checkpoint: { 'channel_values' => { 'status' => 'Planning' } })
    end

    subject(:presenter) { described_class.new(checkpoint, current_user: user) }

    def status_blob(version:, value:, step_action: 'conversation')
      create(:duo_workflows_checkpoint_blob,
        workflow: workflow, thread_ts: 'ts-1', current_thread: 0, channel: 'status',
        version: version, step_action: step_action, data: Zlib::Deflate.deflate(Gitlab::Json.dump(value)))
    end

    # The blob read walks headers (Workflow#ancestor_thread_ts) to resolve the
    # ancestor chain; without one, no blobs are on-path and the read falls back
    # to the header.
    def header
      create(:duo_workflows_checkpoint_header,
        workflow: workflow, thread_ts: 'ts-1', parent_ts: nil, current_thread: 0)
    end

    before do
      stub_feature_flags(duo_workflow_read_incremental_checkpoints: project, dw_read_blobs_graphql: project)
    end

    it 'folds the status deltas to the latest value, ignoring the header' do
      header
      status_blob(version: '1', value: 'Planning')
      status_blob(version: '2', value: 'Executing')

      expect(presenter.execution_status).to eq('Executing')
    end

    it 'reads a compaction delta as the full replacement value' do
      header
      status_blob(version: '1', value: 'Planning')
      status_blob(version: '2', value: 'Executing', step_action: 'compaction')

      expect(presenter.execution_status).to eq('Executing')
    end

    it 'falls back to the workflow status when the reconstructed status is Not Started' do
      header
      status_blob(version: '1', value: 'Not Started')

      expect(presenter.execution_status).to eq(workflow.human_status_name.titleize)
    end

    context 'when no status is reconstructable (no status blob and the header omits it)' do
      let(:checkpoint) do
        create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1', current_thread: 0,
          checkpoint: { 'channel_values' => {} })
      end

      it 'falls back to the workflow status when reconstructed_channel returns nil' do
        header

        expect(presenter.execution_status).to eq(workflow.human_status_name.titleize)
      end
    end

    context 'when the read flag is off' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: false)
      end

      it 'reads the status from the checkpoint header and ignores the blobs' do
        header
        status_blob(version: '1', value: 'Executing')

        expect(presenter.execution_status).to eq('Planning')
      end
    end

    context 'when the kill switch is on but the graphql consumer flag is off' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: project, dw_read_blobs_graphql: false)
      end

      it 'reads the status from the checkpoint header and ignores the blobs' do
        header
        status_blob(version: '1', value: 'Executing')

        expect(presenter.execution_status).to eq('Planning')
      end
    end

    context 'when the workflow was not created with incremental checkpoints' do
      let(:workflow) do
        create(:duo_workflows_workflow, project: project, incremental_checkpoints_enabled: false)
      end

      it 'reads the status from the checkpoint header and ignores the blobs' do
        header
        status_blob(version: '1', value: 'Executing')

        expect(presenter.execution_status).to eq('Planning')
      end
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  describe '#last_duo_message from the checkpoint header' do
    before do
      checkpoint.checkpoint = {
        'channel_values' => {
          'ui_chat_log' => [
            { 'content' => 'earlier', 'message_type' => 'user' },
            { 'content' => 'latest', 'message_type' => 'agent' }
          ]
        }
      }
    end

    it 'returns the last message from the header ui_chat_log' do
      expect(presenter.last_duo_message.content).to eq('latest')
    end

    it 'returns nil when the chat log is empty' do
      checkpoint.checkpoint = { 'channel_values' => { 'ui_chat_log' => [] } }

      expect(presenter.last_duo_message).to be_nil
    end
  end

  describe 'workflow_summary' do
    it 'returns the workflow summary' do
      expect(presenter.workflow_summary).to eq(checkpoint.workflow.summary)
    end
  end
end
