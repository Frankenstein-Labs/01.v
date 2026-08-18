# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::ProgressDeliveryWorker, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:workflow) do
    create(:duo_workflows_workflow,
      messaging_callback_context: { 'adapter' => 'slack', 'team_id' => 'T1', 'channel_id' => 'C1' })
  end

  let(:adapter) { instance_double(Ai::Messaging::Adapters::Slack) }

  before do
    allow(Ai::Messaging::Adapters::Slack).to receive(:from_callback_context).and_return(adapter)
    allow(adapter).to receive(:on_progress)

    create(:duo_workflows_checkpoint,
      workflow: workflow,
      thread_ts: '001',
      checkpoint: { 'channel_values' => { 'ui_chat_log' => [
        { 'message_id' => 'a', 'message_type' => 'agent', 'content' => 'working' }
      ] } })
  end

  describe '#perform' do
    it 'delivers the delta to the adapter and advances the cursor', :aggregate_failures do
      described_class.new.perform(workflow.id)

      expect(adapter).to have_received(:on_progress) do |delta:, callback_context:|
        expect(delta.messages.map { |m| m['message_id'] }).to eq(%w[a])
        expect(callback_context['adapter']).to eq('slack')
      end

      expect(workflow.reload.messaging_callback_context['progress_cursor'])
        .to eq({ 'thread_ts' => '001', 'message_id' => 'a' })
    end

    it 'persists status_ts set by the adapter so the next tick edits in place instead of posting a duplicate',
      :aggregate_failures do
      # Mimic the real adapter: on_progress posts the first message and records
      # its ts on the callback context so subsequent ticks edit the same message.
      allow(adapter).to receive(:on_progress) do |callback_context:, **|
        callback_context['status_ts'] = '9999.0001'
      end

      described_class.new.perform(workflow.id)

      context = workflow.reload.messaging_callback_context
      expect(context['status_ts']).to eq('9999.0001')
      expect(context['progress_cursor']).to eq({ 'thread_ts' => '001', 'message_id' => 'a' })
    end

    it 'persists only the keys this worker owns, not arbitrary context the adapter mutates' do
      # The per-key atomic merge means this worker must not write back keys owned
      # by concurrent writers (e.g. session_url from CallbackWorker).
      allow(adapter).to receive(:on_progress) do |callback_context:, **|
        callback_context['session_url'] = 'https://example.test/should-not-be-persisted'
      end

      described_class.new.perform(workflow.id)

      expect(workflow.reload.messaging_callback_context).not_to have_key('session_url')
    end

    it 'does not re-deliver when the cursor is already current' do
      workflow.update!(messaging_callback_context: workflow.messaging_callback_context.merge(
        'progress_cursor' => { 'thread_ts' => '001', 'message_id' => 'a' }))

      described_class.new.perform(workflow.id)

      expect(adapter).not_to have_received(:on_progress)
    end

    it 'is a no-op once the flow has reached a terminal state' do
      allow_next_found_instance_of(Ai::DuoWorkflows::Workflow) do |instance|
        allow(instance).to receive(:status_terminal?).and_return(true)
      end

      described_class.new.perform(workflow.id)

      expect(adapter).not_to have_received(:on_progress)
    end

    it 'skips workflows without a messaging callback context' do
      other = create(:duo_workflows_workflow)

      described_class.new.perform(other.id)

      expect(adapter).not_to have_received(:on_progress)
    end

    it 'silently skips workflows whose adapter key is unknown', :aggregate_failures do
      unknown = create(:duo_workflows_workflow, messaging_callback_context: { 'adapter' => 'nope' })

      expect { described_class.new.perform(unknown.id) }.not_to raise_error
      expect(adapter).not_to have_received(:on_progress)
    end

    it 'swallows adapter errors so a failed tick never blocks the run', :aggregate_failures do
      allow(adapter).to receive(:on_progress).and_raise(StandardError, 'boom')
      expect(::Gitlab::ErrorTracking).to receive(:track_exception)

      expect { described_class.new.perform(workflow.id) }.not_to raise_error
    end
  end

  describe 'deduplication' do
    it 'coalesces a burst and protects the trailing frame', :aggregate_failures do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
      expect(described_class.get_deduplication_options)
        .to include(including_scheduled: true, if_deduplicated: :reschedule_once)
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [workflow.id] }
  end
end
