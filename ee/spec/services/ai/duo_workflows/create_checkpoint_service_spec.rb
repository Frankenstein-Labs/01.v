# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateCheckpointService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:workflow) { create(:duo_workflows_workflow, **container_params) }
    let(:container_params) { { project: project } }
    let(:thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:parent_ts) { Gitlab::Utils.uuid_v7 }
    let(:metadata) { { another_key: 'another value' } }
    let(:channel_blobs) { nil }
    let(:params) do
      { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' }, metadata: metadata,
        channel_blobs: channel_blobs }
    end

    before do
      allow(GraphqlTriggers).to receive(:workflow_events_updated)
    end

    subject(:execute) do
      described_class
        .new(workflow: workflow, params: params)
        .execute
    end

    it 'creates a new checkpoint' do
      expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
      expect(execute[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
      expect(execute[:checkpoint].workflow).to eq(workflow)
      expect(execute[:checkpoint].project).to eq(project)
      expect(execute[:checkpoint].thread_ts).to eq(thread_ts)
      expect(execute[:checkpoint].parent_ts).to eq(parent_ts)
      expect(execute[:checkpoint].checkpoint).to eq({ 'key' => 'value' })
      expect(execute[:checkpoint].metadata).to eq({ 'another_key' => 'another value' })
      expect(GraphqlTriggers).to have_received(:workflow_events_updated).with(execute[:checkpoint])
    end

    context 'with messaging progress delivery' do
      context 'when the workflow is not messaging-triggered' do
        it 'does not enqueue a progress delivery' do
          expect(Ai::Messaging::ProgressDeliveryWorker).not_to receive(:perform_in)

          execute
        end
      end

      context 'when a messaging workflow whose adapter streams live progress' do
        let(:workflow) do
          create(:duo_workflows_workflow, project: project, messaging_callback_context: { 'adapter' => 'slack' })
        end

        it 'enqueues a debounced progress delivery' do
          expect(Ai::Messaging::ProgressDeliveryWorker)
            .to receive(:perform_in)
            .with(Ai::Messaging::ProgressDeliveryWorker::DEBOUNCE_INTERVAL, workflow.id)

          execute
        end
      end

      context 'when a messaging workflow whose adapter does not stream live progress' do
        let(:workflow) do
          create(:duo_workflows_workflow, project: project, messaging_callback_context: { 'adapter' => 'unknown' })
        end

        it 'does not enqueue a progress delivery' do
          expect(Ai::Messaging::ProgressDeliveryWorker).not_to receive(:perform_in)

          execute
        end
      end
    end

    context 'when namespace-level workflow' do
      let(:container_params) { { namespace: group } }

      it 'creates a new checkpoint' do
        expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
        expect(execute[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
        expect(execute[:checkpoint].workflow).to eq(workflow)
        expect(execute[:checkpoint].namespace).to eq(group)
      end
    end

    context 'when there is invalid params' do
      let(:thread_ts) { '' }

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message].to_s).to include("can't be blank")
        expect(GraphqlTriggers).not_to have_received(:workflow_events_updated).with(execute[:checkpoint])
      end
    end

    describe 'setting goal when first checkpoint' do
      let(:goal) { 'Hello, World!' }
      let(:checkpoint) do
        {
          "channel_values" => {
            "__start__" => {
              "goal" => goal
            }
          }
        }
      end

      let(:params) { { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata } }

      context 'when first checkpoint' do
        it 'updates the workflows goal to be new goal' do
          expect { execute }.to change { workflow.reload.goal }.to('Hello, World!')
        end

        context 'when goal is nil' do
          let(:goal) { nil }

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when goal is blank' do
          let(:goal) { '' }

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when goal field is not present' do
          let(:checkpoint) do
            {
              "channel_values" => {
                "__start__" => {
                  "another_goal" => goal
                }
              }
            }
          end

          it 'does not update the workflows goal' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when __start__ is absent' do
          let(:checkpoint) do
            {
              "channel_values" => {}
            }
          end

          # `dig` returns nil here; a non-`dig` lookup such as `start['goal']`
          # would raise NoMethodError and 500 the checkpoint-create request.
          it 'does not raise and does not update the workflows goal', :aggregate_failures do
            original_goal = workflow.goal

            expect { execute }.not_to raise_error
            expect(workflow.reload.goal).to eq(original_goal)
          end
        end

        context 'when the goal is only at __start__.context.goal (pre-created CLI workflow)' do
          let(:checkpoint) do
            {
              "channel_values" => {
                "__start__" => {
                  "status" => "Not Started",
                  "context" => { "goal" => "What was the last commit?" }
                }
              }
            }
          end

          it 'backfills the goal from the nested context goal' do
            expect { execute }.to change { workflow.reload.goal }.to('What was the last commit?')
          end
        end

        context 'when __start__.goal is blank and the goal is at __start__.context.goal' do
          let(:checkpoint) do
            {
              "channel_values" => {
                "__start__" => {
                  "goal" => "",
                  "context" => { "goal" => "What was the last commit?" }
                }
              }
            }
          end

          it 'backfills the goal from the nested context goal' do
            expect { execute }.to change { workflow.reload.goal }.to('What was the last commit?')
          end
        end

        context 'when goal exceeds the maximum length' do
          let(:goal) { 'a' * (Ai::DuoWorkflows::Workflow::GOAL_MAX_LENGTH + 1) }

          it 'truncates the goal to the maximum length without raising', :aggregate_failures do
            expect { execute }.not_to raise_error
            expect(workflow.reload.goal.length).to eq(Ai::DuoWorkflows::Workflow::GOAL_MAX_LENGTH)
          end
        end
      end

      context 'when not first checkpoint' do
        let!(:existing_checkpoint) do
          create(:duo_workflows_checkpoint, workflow: workflow)
        end

        it 'does not update the workflows goal' do
          expect { execute }.to not_change { workflow.reload.goal }
        end
      end

      it 'detects the first checkpoint without a MIN(id) aggregate scan', :aggregate_failures do
        recorder = ActiveRecord::QueryRecorder.new { execute }

        expect(recorder.log).not_to include(a_string_matching(/MIN\(/i))
        expect(recorder.log).to include(a_string_matching(/SELECT 1 .*p_duo_workflows_checkpoints.*LIMIT 1/im))
      end
    end

    describe 'persisting model metadata' do
      context 'when model_metadata_json is present' do
        let(:model_metadata) { '{"model":"claude-3"}' }
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' },
            metadata: metadata, model_metadata_json: model_metadata }
        end

        it 'persists model_metadata_json on the workflow' do
          execute
          expect(workflow.reload.model_metadata_json).to eq(model_metadata)
        end

        it 'does not pass model_metadata_json to the checkpoint' do
          execute
          expect(execute[:checkpoint].reload.attributes).not_to have_key('model_metadata_json')
        end
      end

      context 'when model_metadata_json is blank' do
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' },
            metadata: metadata, model_metadata_json: '' }
        end

        it 'does not update model_metadata_json on the workflow' do
          expect { execute }.to not_change { workflow.reload.model_metadata_json }
        end
      end

      context 'when model_metadata_json is not provided' do
        it 'does not update model_metadata_json on the workflow' do
          expect { execute }.to not_change { workflow.reload.model_metadata_json }
        end
      end
    end

    describe 'persisting flow metadata' do
      context 'when flow_metadata_json is present' do
        let(:flow_metadata) { '{"flow":"software_development"}' }
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' },
            metadata: metadata, flow_metadata_json: flow_metadata }
        end

        it 'persists flow_metadata_json on the workflow' do
          execute
          expect(workflow.reload.flow_metadata_json).to eq(flow_metadata)
        end

        it 'does not pass flow_metadata_json to the checkpoint' do
          execute
          expect(execute[:checkpoint].reload.attributes).not_to have_key('flow_metadata_json')
        end
      end

      context 'when flow_metadata_json is blank' do
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' },
            metadata: metadata, flow_metadata_json: '' }
        end

        it 'does not update flow_metadata_json on the workflow' do
          expect { execute }.to not_change { workflow.reload.flow_metadata_json }
        end
      end

      context 'when flow_metadata_json is not provided' do
        it 'does not update flow_metadata_json on the workflow' do
          expect { execute }.to not_change { workflow.reload.flow_metadata_json }
        end
      end
    end

    context 'with channel_blobs and incremental checkpoints enabled on the workflow' do
      let(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: true, **container_params) }
      let(:channel_blobs) do
        [
          { channel: 'messages', version: '1', write_type: 'msgpack',
            step_action: 'conversation', data: Base64.strict_encode64('blob1') },
          { channel: 'search', version: '1', write_type: 'msgpack',
            step_action: 'compaction', data: Base64.strict_encode64('blob2') }
        ]
      end

      let(:params) do
        { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' }, metadata: metadata,
          channel_blobs: channel_blobs, current_thread: 2 }
      end

      before do
        stub_feature_flags(duo_workflow_write_incremental_only: false)
      end

      it 'creates the checkpoint and blobs atomically' do
        expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
          .and change { workflow.reload.checkpoint_blobs.count }.by(2)

        checkpoint = workflow.checkpoints.order(:id).last
        expect(checkpoint.current_thread).to eq(2)

        blobs = workflow.checkpoint_blobs.order(:id)
        expect(blobs.map(&:channel)).to eq(%w[messages search])
        expect(blobs.map(&:thread_ts).uniq).to eq([thread_ts])
        expect(blobs.map(&:step_action)).to eq(%w[conversation compaction])
        expect(blobs.map(&:current_thread).uniq).to eq([2])
        # `data` is base64-decoded to raw bytes before it hits the bytea column.
        expect(blobs.map(&:data)).to eq(%w[blob1 blob2])
      end

      it 'returns success with the checkpoint' do
        result = execute
        expect(result[:status]).to eq(:success)
        expect(result[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
      end

      context 'when the workflow is also updated in the same request' do
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' }, metadata: metadata,
            channel_blobs: channel_blobs, current_thread: 2, model_metadata_json: '{"model":"claude-3"}' }
        end

        # Regression: blobs were built on the `@workflow.checkpoint_blobs`
        # association and persisted with `bulk_insert!`, which leaves them
        # unpersisted in memory. The subsequent `@workflow.update!` (here from
        # model metadata) autosaved the association and inserted every blob a
        # second time.
        it 'writes each blob exactly once' do
          expect { execute }.to change { workflow.reload.checkpoint_blobs.count }.by(channel_blobs.size)

          written = workflow.checkpoint_blobs.pluck(:channel, :version)
          expect(written).to match_array(written.uniq)
        end
      end

      it 'anchors blob workflow_created_at to the workflow created_at (partition key), keeping created_at honest' do
        workflow.update!(created_at: 3.days.ago)

        execute

        blobs = workflow.checkpoint_blobs
        # Partition key mirrors the workflow's created_at (compared at DB precision).
        expect(blobs.map(&:workflow_created_at).uniq).to eq([workflow.reload.created_at])
        # created_at is the real write time, not the workflow's (3-days-ago) created_at.
        expect(blobs.map(&:created_at)).to all(be_within(1.minute).of(Time.current))
      end

      it 'skips duplicate blobs when the same delta is re-sent' do
        # A redundant re-send repeats the same thread_ts, so blobs collide on the
        # unique index and are skipped; only the checkpoint row (not deduped) doubles.
        described_class.new(workflow: workflow, params: params).execute
        expect(workflow.reload.checkpoint_blobs.count).to eq(2)

        expect { described_class.new(workflow: workflow, params: params).execute }
          .to not_change { workflow.reload.checkpoint_blobs.count }
      end

      context 'when a re-send carries a compaction for an already-stored version' do
        let(:resend_blobs) do
          [
            # Same (channel, version) as the first send but step_action=compaction:
            # a force_rewrite re-emits the full value, and it must NOT be deduped.
            { channel: 'messages', version: '1', write_type: 'msgpack',
              step_action: 'compaction', data: Base64.strict_encode64('blob1-full') }
          ]
        end

        it 'stores it alongside the conversation delta' do
          execute

          resend = params.merge(channel_blobs: resend_blobs)
          expect { described_class.new(workflow: workflow, params: resend).execute }
            .to change { workflow.reload.checkpoint_blobs.count }.by(1)

          messages = workflow.checkpoint_blobs.where(channel: 'messages', version: '1')
          expect(messages.map(&:step_action)).to match_array(%w[conversation compaction])
        end
      end

      context 'when checkpoint save fails' do
        let(:thread_ts) { '' }

        it 'rolls back blobs and returns error', :aggregate_failures do
          result = nil
          expect { result = execute }.not_to change { Ai::DuoWorkflows::CheckpointBlob.count }
          expect(result[:status]).to eq(:error)
        end
      end
    end

    context 'with incremental checkpoints enabled on the workflow' do
      let(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: true, **container_params) }
      let(:checkpoint) do
        { 'v' => 1, 'channel_versions' => { 'messages' => '1' },
          'channel_values' => { 'messages' => %w[a b], 'ui_chat_log' => [{ 'x' => 1 }] } }
      end

      let(:params) do
        { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata, current_thread: 2 }
      end

      before do
        stub_feature_flags(duo_workflow_write_incremental_only: false)
      end

      it 'shadow-writes a slim header with channel_values stripped' do
        expect { execute }.to change { workflow.reload.checkpoint_headers.count }.by(1)

        written = workflow.checkpoint_headers.order(:id).last
        expect(written.thread_ts).to eq(thread_ts)
        expect(written.parent_ts).to eq(parent_ts)
        expect(written.current_thread).to eq(2)
        expect(written.metadata).to eq(metadata.stringify_keys)
        # channel_values lives in the blobs; the header keeps only the rest.
        expect(written.checkpoint).to eq({ 'v' => 1, 'channel_versions' => { 'messages' => '1' } })
      end

      it 'records the live channel membership' do
        execute

        expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to eq(%w[messages ui_chat_log])
      end

      context 'when a channel has a version but no value (consumed since the last checkpoint)' do
        let(:checkpoint) do
          { 'v' => 1, 'channel_versions' => { 'messages' => '1', 'branch:to:agent' => '2' },
            'channel_values' => { 'messages' => %w[a b] } }
        end

        # channel_versions keeps consumed channels, so it cannot stand in for membership.
        it 'records only the channels that still have a value' do
          execute

          expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to eq(%w[messages])
        end
      end

      context 'when the checkpoint has no channel_values' do
        let(:checkpoint) { { 'v' => 1, 'channel_versions' => {} } }

        it 'writes no membership, which the read path reads as "not recorded"' do
          execute

          expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to be_nil
        end
      end

      context 'when channel_values is empty' do
        let(:checkpoint) { { 'v' => 1, 'channel_values' => {} } }

        it 'writes an empty membership, distinct from "not recorded"' do
          execute

          expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to eq([])
        end
      end

      context 'when channel_values is not a hash' do
        let(:checkpoint) { { 'v' => 1, 'channel_values' => %w[messages] } }

        it 'writes no membership instead of raising' do
          expect { execute }.to change { workflow.reload.checkpoint_headers.count }.by(1)

          expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to be_nil
        end
      end

      context 'with a checkpoint_ns' do
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata,
            current_thread: 2, checkpoint_ns: 'research_agent:0f8ba4c5' }
        end

        it 'copies the langgraph namespace onto the header' do
          execute

          expect(workflow.checkpoint_headers.order(:id).last.checkpoint_ns).to eq('research_agent:0f8ba4c5')
        end
      end

      context 'with a blank checkpoint_ns' do
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata,
            current_thread: 2, checkpoint_ns: '' }
        end

        it 'writes nil, matching the normalization the checkpoint applies' do
          execute

          expect(workflow.checkpoint_headers.order(:id).last.checkpoint_ns).to be_nil
        end
      end

      it 'anchors header workflow_created_at to the workflow created_at, keeping created_at honest' do
        workflow.update!(created_at: 3.days.ago)

        execute

        header = workflow.checkpoint_headers.order(:id).last
        expect(header.workflow_created_at).to eq(workflow.reload.created_at)
        expect(header.created_at).to be_within(1.minute).of(Time.current)
      end

      context 'when the checkpoint is only channel_values (slim header is empty)' do
        let(:checkpoint) { { 'channel_values' => { '__start__' => { 'goal' => 'g' } } } }

        it 'still persists the checkpoint and writes an (empty) header' do
          expect { execute }
            .to change { workflow.reload.checkpoints.count }.by(1)
            .and change { workflow.reload.checkpoint_headers.count }.by(1)

          expect(execute[:status]).to eq(:success)
          expect(workflow.checkpoint_headers.order(:id).last.checkpoint).to eq({})
        end
      end

      it 'appends another header when the same checkpoint is re-sent (no dedup)' do
        execute
        expect(workflow.reload.checkpoint_headers.count).to eq(1)

        # Append-only, like p_duo_workflows_checkpoints; readers take the latest.
        expect { described_class.new(workflow: workflow, params: params).execute }
          .to change { workflow.reload.checkpoint_headers.count }.by(1)
      end

      context 'when a header already exists but the full row was pruned (30-day TTL)' do
        let(:checkpoint) { { 'channel_values' => { '__start__' => { 'goal' => 'A new goal' } } } }
        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata }
        end

        before do
          create(:duo_workflows_checkpoint_header, workflow: workflow)
        end

        # First-run detection reads headers, not the full table, so an aged-out
        # full row does not make this look like the first checkpoint again.
        it 'is not treated as the first checkpoint and does not re-backfill the goal' do
          expect { execute }.to not_change { workflow.reload.goal }
        end
      end
    end

    context 'with incremental checkpoints enabled and write_incremental_only enabled' do
      let(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: true, **container_params) }
      let(:checkpoint) do
        { 'v' => 1, 'channel_versions' => { 'messages' => '1' },
          'channel_values' => { 'messages' => %w[a b] } }
      end

      let(:channel_blobs) do
        [{ channel: 'messages', version: '1', write_type: 'json',
           step_action: 'conversation', data: Base64.strict_encode64('blob') }]
      end

      let(:params) do
        { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: checkpoint, metadata: metadata,
          channel_blobs: channel_blobs, current_thread: 2 }
      end

      it 'writes only the header and blobs, not the full checkpoint row' do
        expect { execute }
          .to change { workflow.reload.checkpoint_headers.count }.by(1)
          .and change { workflow.reload.checkpoint_blobs.count }.by(1)
          .and not_change { workflow.reload.checkpoints.count }
      end

      it 'records the live channel membership on the header' do
        execute

        expect(workflow.checkpoint_headers.order(:id).last.channel_keys).to eq(%w[messages])
      end

      it 'returns success with the (unpersisted) checkpoint' do
        result = execute

        expect(result[:status]).to eq(:success)
        expect(result[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
        expect(result[:checkpoint]).not_to be_persisted
        expect(GraphqlTriggers).to have_received(:workflow_events_updated).with(result[:checkpoint])
      end

      context 'when the checkpoint payload is invalid' do
        let(:thread_ts) { '' }

        it 'writes nothing and returns an error', :aggregate_failures do
          result = nil

          expect { result = execute }
            .to not_change { Ai::DuoWorkflows::CheckpointHeader.count }
            .and not_change { Ai::DuoWorkflows::CheckpointBlob.count }
          expect(result[:status]).to eq(:error)
          expect(result[:message].to_s).to include("can't be blank")
        end
      end

      context 'when it is the first checkpoint' do
        let(:checkpoint) do
          { 'channel_values' => { '__start__' => { 'goal' => 'Hello, World!' } } }
        end

        it 'backfills the workflow goal from the header (no full row exists)' do
          expect { execute }.to change { workflow.reload.goal }.to('Hello, World!')
        end

        # Regression: the checkpoint was built on the `@workflow.checkpoints`
        # association, so the goal backfill's `@workflow.update!` autosaved it and
        # wrote the legacy row that incremental-only exists to skip.
        it 'still writes no full checkpoint row' do
          expect { execute }.to not_change { workflow.reload.checkpoints.count }
        end
      end

      context 'when it is not the first checkpoint' do
        let(:checkpoint) do
          { 'channel_values' => { '__start__' => { 'goal' => 'A new goal' } } }
        end

        before do
          create(:duo_workflows_checkpoint_header, workflow: workflow)
        end

        # first_checkpoint? reads the header table (no full row exists here), so
        # an existing header marks this as not-first and the goal is kept.
        it 'does not re-backfill the workflow goal' do
          expect { execute }.to not_change { workflow.reload.goal }
        end
      end

      # The gateway drops channel_values from the payload once it learns the flag
      # is on, so the checkpoint is the skeleton and the blobs carry the state.
      context 'when the payload carries no channel_values' do
        let(:checkpoint) do
          { 'v' => 3, 'ts' => '2026-08-13T10:00:00Z', 'id' => thread_ts,
            'channel_versions' => { '__start__' => '1' }, 'versions_seen' => {}, 'updated_channels' => nil }
        end

        let(:start_blob_data) { Zlib::Deflate.deflate({ 'goal' => 'Fix the flaky spec' }.to_json) }
        let(:channel_blobs) do
          [{ channel: '__start__', version: '1', write_type: 'json',
             step_action: 'compaction', data: Base64.strict_encode64(start_blob_data) }]
        end

        it 'writes the whole skeleton to the header, plus the blobs', :aggregate_failures do
          expect { execute }
            .to change { workflow.reload.checkpoint_headers.count }.by(1)
            .and change { workflow.reload.checkpoint_blobs.count }.by(1)
            .and not_change { workflow.reload.checkpoints.count }

          expect(execute[:status]).to eq(:success)
          expect(workflow.checkpoint_headers.order(:id).last.checkpoint).to eq(checkpoint)
        end

        it 'backfills the workflow goal from the __start__ blob' do
          expect { execute }.to change { workflow.reload.goal }.to('Fix the flaky spec')
        end

        context 'when the blob read gate is off' do
          before do
            stub_feature_flags(duo_workflow_read_incremental_checkpoints: false)
          end

          # Same gate as every other blob read, so this consumer can't get ahead
          # of the rollout. The payload has no channel_values to fall back to.
          it 'leaves the goal alone' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end

        context 'when the goal is nested under context (pre-created CLI workflow)' do
          let(:start_blob_data) do
            Zlib::Deflate.deflate({ 'context' => { 'goal' => 'What was the last commit?' } }.to_json)
          end

          it 'backfills the goal from the nested context goal' do
            expect { execute }.to change { workflow.reload.goal }.to('What was the last commit?')
          end
        end

        context 'when the __start__ blob is not decodable' do
          let(:start_blob_data) { 'not zlib' }

          it 'writes the checkpoint and leaves the goal alone', :aggregate_failures do
            expect(::Gitlab::ErrorTracking).to receive(:track_exception)
              .with(instance_of(::Gitlab::DuoWorkflow::ChannelValuesReconstructor::CorruptBlobError),
                workflow_id: workflow.id)

            result = nil
            expect { result = execute }
              .to change { workflow.reload.checkpoint_blobs.count }.by(1)
              .and not_change { workflow.reload.goal }
            expect(result[:status]).to eq(:success)
          end
        end

        # The backfill runs after the header and blobs commit, so no decode failure,
        # whatever its class, may turn an already-written checkpoint into an error.
        context 'when decoding the __start__ blob fails unexpectedly' do
          before do
            allow(::Gitlab::DuoWorkflow::ChannelValuesReconstructor)
              .to receive(:decode).and_raise(TypeError, 'no implicit conversion')
          end

          it 'writes the checkpoint and leaves the goal alone', :aggregate_failures do
            expect(::Gitlab::ErrorTracking).to receive(:track_exception)
              .with(instance_of(TypeError), workflow_id: workflow.id)

            result = nil
            expect { result = execute }
              .to change { workflow.reload.checkpoint_blobs.count }.by(1)
              .and not_change { workflow.reload.goal }
            expect(result[:status]).to eq(:success)
          end
        end

        context 'when no blob carries __start__' do
          let(:channel_blobs) do
            [{ channel: 'ui_chat_log', version: '1', write_type: 'json', step_action: 'conversation',
               data: Base64.strict_encode64(Zlib::Deflate.deflate([{ 'content' => 'hi' }].to_json)) }]
          end

          it 'leaves the goal alone' do
            expect { execute }.to not_change { workflow.reload.goal }
          end
        end
      end
    end

    context 'with incremental checkpoints disabled on the workflow' do
      let(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: false, **container_params) }

      it 'does not shadow-write a header' do
        expect { execute }.to not_change { Ai::DuoWorkflows::CheckpointHeader.count }
      end
    end

    context 'with channel_blobs and incremental checkpoints disabled on the workflow' do
      let(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: false, **container_params) }
      let(:channel_blobs) do
        [{ channel: 'messages', version: '1', write_type: 'msgpack',
           step_action: 'conversation', data: Base64.strict_encode64('blob') }]
      end

      it 'ignores channel_blobs and creates the checkpoint only' do
        expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
          .and not_change { Ai::DuoWorkflows::CheckpointBlob.count }
      end

      context 'when the payload carries no channel_values' do
        let(:channel_blobs) do
          [{ channel: '__start__', version: '1', write_type: 'json', step_action: 'compaction',
             data: Base64.strict_encode64(Zlib::Deflate.deflate({ 'goal' => 'From a blob' }.to_json)) }]
        end

        let(:params) do
          { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { 'id' => thread_ts },
            metadata: metadata, channel_blobs: channel_blobs }
        end

        # These blobs are never stored, so the goal must not come from them.
        it 'does not read the goal from the blobs' do
          expect { execute }.to not_change { workflow.reload.goal }
        end
      end
    end
  end
end
