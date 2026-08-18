# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::ProgressReader, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }

  let(:reader) { described_class.new }

  def create_checkpoint(thread_ts:, messages:)
    create(:duo_workflows_checkpoint,
      workflow: workflow,
      thread_ts: thread_ts,
      checkpoint: { 'channel_values' => { 'ui_chat_log' => messages } })
  end

  def msg(id, type: 'agent', content: 'hi', tool: nil)
    {
      'message_id' => id,
      'message_type' => type,
      'content' => content,
      'tool_info' => tool && { 'name' => tool }
    }
  end

  describe '#delta_since' do
    context 'when there are no checkpoints' do
      it 'returns an empty delta and preserves the cursor', :aggregate_failures do
        delta = reader.delta_since(workflow, cursor: { 'thread_ts' => 'x' })

        expect(delta).to be_empty
        expect(delta.cursor).to eq({ 'thread_ts' => 'x' })
      end
    end

    context 'with a nil cursor (first read)' do
      before do
        create_checkpoint(thread_ts: '001', messages: [msg('a'), msg('b', tool: 'todo_write')])
      end

      it 'returns the whole log as both snapshot and new entries', :aggregate_failures do
        delta = reader.delta_since(workflow, cursor: nil)

        expect(delta.messages.map { |m| m['message_id'] }).to eq(%w[a b])
        expect(delta.new_messages.map { |m| m['message_id'] }).to eq(%w[a b])
        expect(delta.cursor).to eq({ 'thread_ts' => '001', 'message_id' => 'b' })
      end
    end

    context 'when the latest checkpoint has not advanced' do
      before do
        create_checkpoint(thread_ts: '001', messages: [msg('a')])
      end

      it 'returns an empty delta (cheap no-op guard)' do
        delta = reader.delta_since(workflow, cursor: { 'thread_ts' => '001', 'message_id' => 'a' })

        expect(delta).to be_empty
      end
    end

    context 'when a newer checkpoint has advanced' do
      before do
        create_checkpoint(thread_ts: '001', messages: [msg('a'), msg('b')])
        create_checkpoint(thread_ts: '002', messages: [msg('a'), msg('b'), msg('c'), msg('d')])
      end

      it 'returns the full snapshot and only the new entries as the delta', :aggregate_failures do
        delta = reader.delta_since(workflow, cursor: { 'thread_ts' => '001', 'message_id' => 'b' })

        expect(delta.messages.map { |m| m['message_id'] }).to eq(%w[a b c d])
        expect(delta.new_messages.map { |m| m['message_id'] }).to eq(%w[c d])
        expect(delta.cursor).to eq({ 'thread_ts' => '002', 'message_id' => 'd' })
      end
    end

    context 'when the cursor message_id is no longer present (e.g. compaction)' do
      before do
        create_checkpoint(thread_ts: '002', messages: [msg('x'), msg('y')])
      end

      it 'treats the whole log as new', :aggregate_failures do
        delta = reader.delta_since(workflow, cursor: { 'thread_ts' => '001', 'message_id' => 'gone' })

        expect(delta.messages.map { |m| m['message_id'] }).to eq(%w[x y])
        expect(delta.new_messages.map { |m| m['message_id'] }).to eq(%w[x y])
      end
    end

    context 'when reading from incremental checkpoint blobs (notifications gate on)' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: true, dw_read_blobs_notifications: true)
        workflow.update!(incremental_checkpoints_enabled: true)
      end

      def create_header(thread_ts:, parent_ts:)
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: thread_ts, parent_ts: parent_ts,
          current_thread: 0, workflow_created_at: workflow.created_at)
      end

      def create_log_blob(thread_ts:, version:, messages:)
        create(:duo_workflows_checkpoint_blob, workflow: workflow, thread_ts: thread_ts, current_thread: 0,
          channel: 'ui_chat_log', version: version, write_type: 'json', step_action: 'conversation',
          workflow_created_at: workflow.created_at, data: Zlib::Deflate.deflate(Gitlab::Json.dump(messages)))
      end

      it 'reconstructs the log from blobs and reports the delta like the legacy path', :aggregate_failures do
        # Slim headers carry no channel_values; the log is folded from the blobs.
        create_header(thread_ts: '001', parent_ts: nil)
        create_header(thread_ts: '002', parent_ts: '001')
        create_log_blob(thread_ts: '001', version: '1', messages: [msg('a'), msg('b')])
        create_log_blob(thread_ts: '002', version: '2', messages: [msg('c'), msg('d')])

        delta = reader.delta_since(workflow, cursor: { 'thread_ts' => '001', 'message_id' => 'b' })

        expect(delta.messages.map { |m| m['message_id'] }).to eq(%w[a b c d])
        expect(delta.new_messages.map { |m| m['message_id'] }).to eq(%w[c d])
        expect(delta.cursor).to eq({ 'thread_ts' => '002', 'message_id' => 'd' })
      end
    end
  end
end
