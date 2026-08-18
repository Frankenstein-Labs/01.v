# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::ChannelValuesReconstructor, feature_category: :duo_agent_platform do
  # Mirror the gateway wire format: data is zlib-compressed JSON.
  def blob(channel:, version:, value:, step_action: 'conversation', thread_ts: 'ts-1')
    instance_double(
      Ai::DuoWorkflows::CheckpointBlob,
      channel: channel,
      version: version,
      step_action: step_action,
      thread_ts: thread_ts,
      data: Zlib::Deflate.deflate(Gitlab::Json.dump(value))
    )
  end

  subject(:channel_values) { described_class.new(blobs).channel_values }

  context 'with a list (append) channel' do
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }, { 'content' => 'c' }])
      ]
    end

    it 'concatenates the deltas in version order' do
      expect(channel_values).to eq(
        'ui_chat_log' => [{ 'content' => 'a' }, { 'content' => 'b' }, { 'content' => 'c' }]
      )
    end
  end

  context 'with a dict-of-list channel' do
    let(:blobs) do
      [
        blob(channel: 'conversation_history', version: '1', value: { 'agent' => [{ 'm' => 1 }] }),
        blob(channel: 'conversation_history', version: '2', value: { 'agent' => [{ 'm' => 2 }] })
      ]
    end

    it 'appends each key tail to the accumulated list' do
      expect(channel_values).to eq(
        'conversation_history' => { 'agent' => [{ 'm' => 1 }, { 'm' => 2 }] }
      )
    end
  end

  context 'with a compaction delta' do
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
        blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'compacted' }],
          step_action: 'compaction')
      ]
    end

    it 'replaces the accumulated value with the full compacted value' do
      expect(channel_values).to eq('ui_chat_log' => [{ 'content' => 'compacted' }])
    end
  end

  context 'with a self-contained group (compaction snapshot then conversation deltas)' do
    # Mirrors AIGW self-contained groups: a group opens with a full compaction
    # snapshot, then later steps append conversation deltas onto it.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
          value: [{ 'content' => 'seed a' }, { 'content' => 'seed b' }]),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'c' }]),
        blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'd' }])
      ]
    end

    it 'seeds from the snapshot and appends the later deltas' do
      expect(channel_values).to eq(
        'ui_chat_log' => [
          { 'content' => 'seed a' }, { 'content' => 'seed b' },
          { 'content' => 'c' }, { 'content' => 'd' }
        ]
      )
    end
  end

  context 'with deltas before and after a mid-chain compaction' do
    # Anchoring starts the fold at the last compaction, so the pre-compaction
    # delta is never replayed; the result is the snapshot plus what follows it.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'pre' }]),
        blob(channel: 'ui_chat_log', version: '2', step_action: 'compaction',
          value: [{ 'content' => 'snapshot' }]),
        blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'post' }])
      ]
    end

    it 'starts from the last compaction and ignores earlier deltas' do
      expect(channel_values).to eq(
        'ui_chat_log' => [{ 'content' => 'snapshot' }, { 'content' => 'post' }]
      )
    end
  end

  context 'with duplicate (channel, version) blobs' do
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }])
      ]
    end

    it 'collapses duplicates so the delta is applied once' do
      expect(channel_values).to eq('ui_chat_log' => [{ 'content' => 'a' }])
    end
  end

  context 'with a conversation and a compaction blob that share a version' do
    # A force_rewrite can store both for one (channel, version). #channel_values
    # anchors on the compaction (the full value), so it wins here.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'delta' }]),
        blob(channel: 'ui_chat_log', version: '2', step_action: 'compaction',
          value: [{ 'content' => 'snapshot' }])
      ]
    end

    it 'anchors on the same-version compaction snapshot' do
      expect(channel_values).to eq('ui_chat_log' => [{ 'content' => 'snapshot' }])
    end
  end

  context 'with a same-version collision whose rows are not adjacent' do
    # The winning v1 compaction arrives after v2. It anchors at the v1 slot, so the v2
    # delta still applies on top of it. Anchoring at the later slot would drop that delta.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'stale' }]),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
        blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
          value: [{ 'content' => 'snapshot' }])
      ]
    end

    it 'anchors at the version first occurrence and keeps the later delta' do
      expect(channel_values).to eq('ui_chat_log' => [{ 'content' => 'snapshot' }, { 'content' => 'b' }])
    end
  end

  context 'with the same version repeated across different thread_ts' do
    # Defense-in-depth: dedup keys on (thread_ts, version), not version alone, so
    # a version number that legitimately repeats across groups isn't mistaken for
    # a same-thread retry and dropped.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }], thread_ts: 'ts-1'),
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'b' }], thread_ts: 'ts-2')
      ]
    end

    it 'keeps both blobs instead of collapsing them as a retry' do
      expect(channel_values).to eq('ui_chat_log' => [{ 'content' => 'a' }, { 'content' => 'b' }])
    end
  end

  context 'with versions that reset across thread_ts' do
    # If DWS ever reset channel_version per group, a numeric sort would place
    # thread B's v1 before thread A's v2, breaking the session's real order.
    # Ordering by chain position (array order) keeps it chronological anyway.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a1' }], thread_ts: 'ts-a'),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'a2' }], thread_ts: 'ts-a'),
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'b1' }], thread_ts: 'ts-b'),
        blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b2' }], thread_ts: 'ts-b')
      ]
    end

    it 'keeps chain order instead of interleaving by numeric version' do
      expect(channel_values).to eq(
        'ui_chat_log' => [
          { 'content' => 'a1' }, { 'content' => 'a2' }, { 'content' => 'b1' }, { 'content' => 'b2' }
        ]
      )
    end
  end

  context 'with versions that sort lexically out of order' do
    # Ordering is by chain position (array order), not by comparing version
    # strings, so "10" naturally follows "9" here without a numeric sort.
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '9', value: [{ 'content' => '9' }]),
        blob(channel: 'ui_chat_log', version: '10', value: [{ 'content' => '10' }])
      ]
    end

    it 'keeps chain order so "10" follows "9"' do
      expect(channel_values).to eq(
        'ui_chat_log' => [{ 'content' => '9' }, { 'content' => '10' }]
      )
    end
  end

  context 'with multiple channels' do
    let(:blobs) do
      [
        blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
        blob(channel: 'context', version: '1', value: { 'goal' => 'x' }, step_action: 'compaction')
      ]
    end

    it 'reconstructs each channel independently' do
      expect(channel_values).to eq(
        'ui_chat_log' => [{ 'content' => 'a' }],
        'context' => { 'goal' => 'x' }
      )
    end
  end

  context 'with no blobs' do
    let(:blobs) { [] }

    it { is_expected.to eq({}) }
  end

  context 'with a corrupted blob' do
    let(:corrupt_blob) do
      instance_double(
        Ai::DuoWorkflows::CheckpointBlob,
        channel: 'ui_chat_log', version: '2', step_action: 'conversation', thread_ts: 'ts-1', data: 'not zlib'
      )
    end

    let(:blobs) do
      [blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]), corrupt_blob]
    end

    it 'raises so the read fails rather than returning inconsistent values' do
      expect { channel_values }.to raise_error(described_class::CorruptBlobError)
    end
  end

  describe '#channel_history' do
    let(:ancestry) { { 'ts-1' => nil, 'ts-2' => 'ts-1' } }
    let(:alternatives) { {} }

    # Every entry is stamped with the checkpoint that introduced it; blobs default
    # to the chain root, whose parent_ts is nil.
    def message(content, thread_ts: 'ts-1', parent_ts: nil)
      { 'content' => content, 'thread_ts' => thread_ts, 'parent_ts' => parent_ts }
    end

    subject(:history) do
      described_class.new(blobs).channel_history('ui_chat_log', ancestry, alternatives)
    end

    context 'with deltas around a mid-chain compaction' do
      # Unlike #channel_values (which anchors at the last compaction), history keeps
      # the pre-compaction deltas and drops the summary snapshot.
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
          blob(channel: 'ui_chat_log', version: '3', step_action: 'compaction',
            value: [{ 'content' => 'summary' }]),
          blob(channel: 'ui_chat_log', version: '4', value: [{ 'content' => 'c' }])
        ]
      end

      it 'keeps every conversation delta and drops the compaction summary' do
        expect(history).to eq([message('a'), message('b'), message('c')])
      end
    end

    context 'with deltas from several checkpoints' do
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', thread_ts: 'ts-2',
            value: [{ 'content' => 'b' }, { 'content' => 'c' }])
        ]
      end

      it 'stamps each message with the checkpoint that introduced it' do
        expect(history).to eq(
          [
            message('a'),
            message('b', thread_ts: 'ts-2', parent_ts: 'ts-1'),
            message('c', thread_ts: 'ts-2', parent_ts: 'ts-1')
          ]
        )
      end
    end

    context 'with a turn the user retried' do
      let(:alternatives) { { 'ts-2' => 1 } }
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a', 'message_type' => 'agent' }]),
          blob(channel: 'ui_chat_log', version: '2', thread_ts: 'ts-2',
            value: [{ 'content' => 'b', 'message_type' => 'user' }, { 'content' => 'c', 'message_type' => 'agent' }])
        ]
      end

      it 'counts alternatives on the user message anchoring the turn, and nowhere else' do
        expect(history.map { |entry| entry.values_at('content', 'alternative_count') })
          .to eq([['a', nil], ['b', 1], ['c', nil]])
      end
    end

    context 'with a turn the user never retried' do
      let(:blobs) do
        [blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a', 'message_type' => 'user' }])]
      end

      it 'reports no alternatives rather than leaving the count unset' do
        expect(history.first['alternative_count']).to eq(0)
      end
    end

    context 'with a checkpoint missing from the ancestry map' do
      let(:ancestry) { {} }
      let(:blobs) { [blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }])] }

      it 'still stamps the thread_ts, leaving the fork point unknown' do
        expect(history).to eq([message('a')])
      end
    end

    context 'with a group-0 seed snapshot' do
      # The earliest snapshot seeds the base (e.g. a resumed workflow's starting log).
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
            value: [{ 'content' => 'seed' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'a' }])
        ]
      end

      it 'seeds from the earliest snapshot and appends the deltas' do
        expect(history).to eq([message('seed'), message('a')])
      end
    end

    context 'with a restart re-seed snapshot after earlier deltas' do
      # A gateway restart re-seeds the full current log as a compaction; its detail
      # is already in the earlier deltas, so history drops it (no double-count).
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
          blob(channel: 'ui_chat_log', version: '3', step_action: 'compaction',
            value: [{ 'content' => 'a' }, { 'content' => 'b' }]),
          blob(channel: 'ui_chat_log', version: '4', value: [{ 'content' => 'c' }])
        ]
      end

      it 'drops the re-seed snapshot and keeps every delta once' do
        expect(history).to eq([message('a'), message('b'), message('c')])
      end
    end

    context 'with other channels present' do
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'context', version: '2', value: { 'goal' => 'x' }, step_action: 'compaction')
        ]
      end

      it 'folds only the requested channel' do
        expect(history).to eq([message('a')])
      end
    end

    context 'with a conversation and a compaction blob that share a version' do
      # This fold drops mid-stream compactions, so it must keep the conversation
      # delta of the colliding version, not the compaction.
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', step_action: 'compaction',
            value: [{ 'content' => 'summary' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }])
        ]
      end

      it 'keeps the conversation delta and drops the same-version compaction' do
        expect(history).to eq([message('a'), message('b')])
      end
    end

    context 'with a same-version collision whose rows are not adjacent' do
      # The v1 retry arrives after v2, so the winning row sits later in the chain. Order
      # comes from where v1 first appeared, otherwise v2 would precede v1 in the history.
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
            value: [{ 'content' => 'stale' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'c' }])
        ]
      end

      it 'places the winning row at the version first occurrence' do
        expect(history).to eq([message('a'), message('b'), message('c')])
      end
    end

    context 'with no blobs for the channel' do
      let(:blobs) { [] }

      it { is_expected.to be_nil }
    end
  end

  describe '#channel_changes' do
    context 'with a replace-semantics channel (status)' do
      subject(:changes) { described_class.new(blobs).channel_changes('status') }

      let(:blobs) do
        [
          blob(channel: 'status', version: '1', value: 'running'),
          blob(channel: 'status', version: '2', value: 'paused'),
          blob(channel: 'status', version: '3', value: 'running')
        ]
      end

      it 'keeps every value the channel took, oldest first' do
        expect(changes).to eq(%w[running paused running])
      end
    end

    context 'with a list channel around a mid-chain compaction' do
      subject(:changes) { described_class.new(blobs).channel_changes('ui_chat_log') }

      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }]),
          blob(channel: 'ui_chat_log', version: '3', step_action: 'compaction',
            value: [{ 'content' => 'summary' }]),
          blob(channel: 'ui_chat_log', version: '4', value: [{ 'content' => 'c' }])
        ]
      end

      it 'expands the message deltas and drops the compaction summary' do
        expect(changes).to eq([{ 'content' => 'a' }, { 'content' => 'b' }, { 'content' => 'c' }])
      end
    end

    context 'with an initial compaction snapshot' do
      subject(:changes) { described_class.new(blobs).channel_changes('ui_chat_log') }

      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
            value: [{ 'content' => 'seed' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'a' }])
        ]
      end

      it 'seeds from the initial snapshot and keeps the later changes' do
        expect(changes).to eq([{ 'content' => 'seed' }, { 'content' => 'a' }])
      end
    end

    context 'with only empty-array deltas before a mid-chain compaction' do
      subject(:changes) { described_class.new(blobs).channel_changes('ui_chat_log') }

      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: []),
          blob(channel: 'ui_chat_log', version: '2', step_action: 'compaction',
            value: [{ 'content' => 'summary' }]),
          blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'a' }])
        ]
      end

      it 'still drops the compaction summary even though no change was emitted yet' do
        expect(changes).to eq([{ 'content' => 'a' }])
      end
    end

    context 'with a conversation and a compaction blob that share a version' do
      subject(:changes) { described_class.new(blobs).channel_changes('ui_chat_log') }

      # Prefer the conversation delta: keeping the compaction instead would drop
      # the change, since #channel_changes skips mid-stream compactions.
      let(:blobs) do
        [
          blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'a' }]),
          blob(channel: 'ui_chat_log', version: '2', step_action: 'compaction',
            value: [{ 'content' => 'summary' }]),
          blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'b' }])
        ]
      end

      it 'keeps the conversation delta of the colliding version' do
        expect(changes).to eq([{ 'content' => 'a' }, { 'content' => 'b' }])
      end
    end

    context 'with no blobs for the channel' do
      subject(:changes) { described_class.new([]).channel_changes('status') }

      it { is_expected.to eq([]) }
    end
  end
end
