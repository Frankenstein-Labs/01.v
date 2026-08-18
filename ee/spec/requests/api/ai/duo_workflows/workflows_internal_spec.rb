# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::WorkflowsInternal, :aggregate_failures, feature_category: :duo_agent_platform do
  include HttpBasicAuthHelpers
  include_context 'workhorse headers'

  let_it_be(:ai_settings, freeze: false) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group, freeze: false) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

  let_it_be(:ai_catalog_item_version) { create(:ai_catalog_item_version) }

  let(:workflow) do
    create(
      :duo_workflows_workflow,
      user: user,
      workflow_definition: workflow_definition,
      pre_approved_agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
      agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
      ai_catalog_item_version_id: ai_catalog_item_version.id,
      summary: "This session succeeded",
      title: "My session title",
      incremental_checkpoints_enabled: true,
      **container_params
    )
  end

  let(:workflow_definition) { 'software_development' }
  let(:container_params) { { project: project } }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:current_time) { Time.current }
    let(:thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:later_thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:parent_ts) { Gitlab::Utils.uuid_v7 }
    let(:checkpoint) { { key: 'value' } }
    let(:metadata) { { key: 'value' } }
    let(:params) { { thread_ts: thread_ts, checkpoint: checkpoint, parent_ts: parent_ts, metadata: metadata } }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    # These specs assert the legacy full checkpoint row. duo_workflow_write_incremental_only
    # (default-on in tests) skips that row, so pin it off to test the dual-write path.
    before do
      stub_feature_flags(duo_workflow_write_incremental_only: false)
    end

    it 'allows creating multiple checkpoints for a workflow' do
      expect do
        post api(path, user), params: params, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:created)

        post api(path, user), params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts),
          headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:created)
      end.to change { workflow.reload.checkpoints.count }.by(2)

      expect(Ai::DuoWorkflows::Checkpoint.distinct.pluck('project_id')).to eq([project.id])

      checkpoint = Ai::DuoWorkflows::Checkpoint.last
      expect(json_response).to eq({
        'id' => checkpoint.id.first,
        'parent_ts' => checkpoint.parent_ts,
        'thread_ts' => checkpoint.thread_ts,
        'checkpoint_ns' => checkpoint.checkpoint_ns
      })
    end

    context 'with checkpoint_ns' do
      let(:params) do
        {
          thread_ts: thread_ts, checkpoint: checkpoint, parent_ts: parent_ts, metadata: metadata,
          checkpoint_ns: 'delegation:task-1'
        }
      end

      it 'persists the checkpoint_ns, scoping the checkpoint to that nested subgraph invocation' do
        post api(path, user), params: params, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:created)

        expect(Ai::DuoWorkflows::Checkpoint.last.checkpoint_ns).to eq('delegation:task-1')
        expect(json_response['checkpoint_ns']).to eq('delegation:task-1')
      end
    end

    context 'with a deeply nested checkpoint_ns' do
      # LangGraph composes checkpoint_ns as one `<node_name>:<task_uuid>` segment per
      # nested subgraph level, joined by `|`, so it grows by ~50 characters per level of
      # subagent nesting. Values well beyond the original 255-character limit must be
      # accepted, otherwise nesting is capped at ~4 levels.
      let(:deep_checkpoint_ns) { Array.new(20) { "research_agent:#{SecureRandom.uuid}" }.join('|') }

      let(:params) do
        {
          thread_ts: thread_ts, checkpoint: checkpoint, parent_ts: parent_ts, metadata: metadata,
          checkpoint_ns: deep_checkpoint_ns
        }
      end

      it 'persists the full checkpoint_ns' do
        expect(deep_checkpoint_ns.length).to be_between(256, 4096)

        post api(path, user), params: params, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:created)

        expect(Ai::DuoWorkflows::Checkpoint.last.checkpoint_ns).to eq(deep_checkpoint_ns)
      end
    end

    context 'without checkpoint_ns' do
      it 'persists a blank checkpoint_ns, representing the top-level flow graph itself' do
        post api(path, user), params: params, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:created)

        expect(Ai::DuoWorkflows::Checkpoint.last.checkpoint_ns).to be_nil
      end
    end

    describe 'setting goal when first checkpoint' do
      let(:checkpoint) do
        {
          "channel_values" => {
            "__start__" => {
              "goal" => "Hello, World!"
            }
          }
        }
      end

      context 'when first checkpoint' do
        it 'updates the workflows goal to be new goal' do
          expect do
            post api(path, user), params: params, headers: workhorse_headers
          end.to change { workflow.reload.goal }.to('Hello, World!')
        end
      end

      context 'when not first checkpoint' do
        # An incremental workflow writes a header for every checkpoint, and
        # first_checkpoint? reads the headers table, so a prior checkpoint has a header.
        let!(:existing_checkpoint) do
          create(:duo_workflows_checkpoint, workflow: workflow)
        end

        let!(:existing_header) do
          create(:duo_workflows_checkpoint_header, workflow: workflow)
        end

        it 'does not update the workflows goal' do
          expect do
            post api(path, user), params: params, headers: workhorse_headers
          end.to not_change { workflow.reload.goal }
        end
      end
    end

    context 'with compressed checkpoint' do
      let(:checkpoint_data) { { 'key' => 'value', 'nested' => { 'data' => 'test' } } }
      let(:compressed_checkpoint) { 'eJyrVspOrVSyUipLzClNVdJRykstLklNUbKqVkpJLEkESpQABZRqawENlQ1i' }
      let(:params) do
        {
          thread_ts: thread_ts,
          compressed_checkpoint: compressed_checkpoint,
          parent_ts: parent_ts,
          metadata: metadata
        }
      end

      it 'successfully creates a checkpoint with compressed data' do
        expect do
          post api(path, user), params: params, headers: workhorse_headers
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.reload.checkpoints.count }.by(1)

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        expect(checkpoint.checkpoint).to eq(checkpoint_data)
      end

      context 'with invalid compressed data' do
        let(:compressed_checkpoint) { 'invalid-zlib-base64' }

        it 'fails to create a checkpoint with error' do
          post api(path, user), params: params, headers: workhorse_headers
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body)
            .to eq({ message: "400 Bad request - Invalid compressed checkpoint data: invalid base64" }.to_json)
        end
      end
    end

    context 'with uncompressed checkpoint' do
      it 'successfully creates a checkpoint with uncompressed data' do
        expect do
          post api(path, user), params: params, headers: workhorse_headers
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.reload.checkpoints.count }.by(1)

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        expect(checkpoint.checkpoint).to eq({ 'key' => 'value' })
      end
    end

    context 'with namespace-level chat workflow' do
      let(:workflow_definition) { 'chat' }
      let(:container_params) { { namespace_id: group.id } }

      it 'has correct attributes in checkpoint records' do
        expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        expect(Ai::DuoWorkflows::Checkpoint.distinct.pluck('namespace_id')).to eq([group.id])
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is successful' do
        post api(path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
      end

      it "fails when request doesn't have workhorse headers" do
        post api(path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it "fails when creating a checkpoint for another user's remote execution workflow" do
        other_user = create(:user, maintainer_of: project)
        other_workflow = create(:duo_workflows_workflow, user: other_user, project: project, environment: :web,
          workflow_definition: :convert_to_gitlab_ci)
        checkpoint_path = "/ai/duo_workflows/workflows/#{other_workflow.id}/checkpoints"

        post api(checkpoint_path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    it 'fails if the thread_ts is an empty string' do
      post api(path, user), params: params.merge(thread_ts: ''), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to include("can't be blank")
    end

    context 'with model_metadata_json' do
      let(:model_metadata) { '{"model":"claude-3"}' }

      it 'persists model_metadata_json on the workflow' do
        post api(path, user), params: params.merge(model_metadata_json: model_metadata), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        expect(workflow.reload.model_metadata_json).to eq(model_metadata)
      end

      it 'creates checkpoint successfully without model_metadata_json' do
        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        expect(workflow.reload.model_metadata_json).to be_nil
      end
    end

    context 'with flow_metadata_json' do
      let(:flow_metadata) { '{"flow":"software_development"}' }

      it 'persists flow_metadata_json on the workflow' do
        post api(path, user), params: params.merge(flow_metadata_json: flow_metadata), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        expect(workflow.reload.flow_metadata_json).to eq(flow_metadata)
      end

      it 'creates checkpoint successfully without flow_metadata_json' do
        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        expect(workflow.reload.flow_metadata_json).to be_nil
      end
    end

    context 'with channel_blobs and the feature flag enabled' do
      let(:channel_blobs) do
        [
          { channel: 'messages', version: '1', write_type: 'msgpack',
            step_action: 'conversation', data: Base64.strict_encode64('blob1') },
          { channel: 'search', version: '2', write_type: 'msgpack',
            step_action: 'compaction', data: Base64.strict_encode64('blob2') }
        ]
      end

      before do
        stub_feature_flags(duo_workflow_incremental_checkpoints: project)
      end

      it 'creates the checkpoint and stores the blobs' do
        expect do
          post api(path, user), params: params.merge(channel_blobs: channel_blobs, current_thread: 1),
            headers: workhorse_headers
        end.to change { workflow.reload.checkpoints.count }.by(1)
          .and change { Ai::DuoWorkflows::CheckpointBlob.count }.by(2)

        expect(response).to have_gitlab_http_status(:created)
        blobs = workflow.checkpoint_blobs.order(:id)
        expect(blobs.map(&:channel)).to eq(%w[messages search])
        expect(blobs.map(&:thread_ts).uniq).to eq([thread_ts])
        expect(blobs.map(&:step_action)).to eq(%w[conversation compaction])
        expect(blobs.map(&:current_thread).uniq).to eq([1])
        # The base64 `data` payload is decoded to raw bytes for the bytea column.
        expect(blobs.map(&:data)).to eq(%w[blob1 blob2])
      end
    end

    context 'with a checkpoint carrying channel_values' do
      let(:checkpoint) do
        { 'v' => 1, 'channel_versions' => { 'messages' => '1', 'branch:to:agent' => '2' },
          'channel_values' => { 'messages' => %w[a b], 'branch:to:agent' => nil } }
      end

      it 'records the live channel membership on the header' do
        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:created)
        header = workflow.checkpoint_headers.order(:id).last
        expect(header.channel_keys).to match_array(['messages', 'branch:to:agent'])
        expect(header.checkpoint).not_to have_key('channel_values')
      end
    end

    context 'when channel_blobs params exceed their limits' do
      before do
        stub_feature_flags(duo_workflow_incremental_checkpoints: project)
      end

      it 'rejects a data value larger than the base64 blob limit before decoding' do
        oversized = 'a' * 1_398_105

        expect do
          post api(path, user),
            params: params.merge(channel_blobs: [{ channel: 'messages', version: '1', write_type: 'msgpack',
                                                   step_action: 'conversation', data: oversized }]),
            headers: workhorse_headers
        end.to not_change { Ai::DuoWorkflows::CheckpointBlob.count }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('must be less than 1398104 characters')
      end

      it 'rejects more than 100 channel_blobs' do
        blobs = Array.new(101) do |i|
          { channel: "c#{i}", version: i.to_s, write_type: 'msgpack',
            step_action: 'conversation', data: Base64.strict_encode64('x') }
        end

        post api(path, user), params: params.merge(channel_blobs: blobs), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('must contain at most 100 items')
      end

      it 'rejects an invalid step_action' do
        post api(path, user),
          params: params.merge(channel_blobs: [{ channel: 'messages', version: '1', write_type: 'msgpack',
                                                 step_action: 'invalid', data: Base64.strict_encode64('blob') }]),
          headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'with channel_blobs and incremental checkpoints disabled on the workflow' do
      let(:workflow) do
        create(
          :duo_workflows_workflow,
          user: user,
          workflow_definition: workflow_definition,
          pre_approved_agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
          agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
          ai_catalog_item_version_id: ai_catalog_item_version.id,
          summary: "This session succeeded",
          title: "My session title",
          incremental_checkpoints_enabled: false,
          **container_params
        )
      end

      let(:channel_blobs) do
        [{ channel: 'messages', version: '1', write_type: 'msgpack',
           step_action: 'conversation', data: Base64.strict_encode64('blob') }]
      end

      it 'ignores channel_blobs and creates the checkpoint only' do
        expect do
          post api(path, user), params: params.merge(channel_blobs: channel_blobs), headers: workhorse_headers
        end.to change { workflow.reload.checkpoints.count }.by(1)
          .and not_change { Ai::DuoWorkflows::CheckpointBlob.count }

        expect(response).to have_gitlab_http_status(:created)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    # These specs assert the legacy checkpoints table, which the factory writes
    # without the header an incremental workflow always gets. dw_read_blobs_list is
    # default-on in tests, so pin it off to keep them on the legacy read path.
    before do
      stub_feature_flags(dw_read_blobs_list: false)
    end

    it 'returns the checkpoints in descending order of thread_ts' do
      checkpoint1 = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint2 = create(:duo_workflows_checkpoint, workflow: workflow)
      workflow.checkpoints << checkpoint1
      workflow.checkpoints << checkpoint2

      get api(path, user), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq([checkpoint2.id.first, checkpoint1.id.first])
      expect(json_response.pluck('thread_ts')).to eq([checkpoint2.thread_ts, checkpoint1.thread_ts])
      expect(json_response.pluck('parent_ts')).to eq([checkpoint2.parent_ts, checkpoint1.parent_ts])
      expect(json_response[0]).to have_key('checkpoint')
      expect(json_response[0]).not_to have_key('compressed_checkpoint')
      expect(json_response[0]).to have_key('metadata')
    end

    it "fails when request doesn't have workhorse headers" do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'with checkpoint_ns parameter' do
      let!(:top_level_checkpoint) { create(:duo_workflows_checkpoint, workflow: workflow) }
      let!(:nested_checkpoint) do
        create(:duo_workflows_checkpoint, workflow: workflow, checkpoint_ns: 'delegation:task-1')
      end

      it 'returns only checkpoints in the given namespace' do
        get api(path, user), params: { checkpoint_ns: 'delegation:task-1' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq([nested_checkpoint.id.first])
      end

      it 'returns only top-level checkpoints for a blank checkpoint_ns' do
        get api(path, user), params: { checkpoint_ns: '' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq([top_level_checkpoint.id.first])
      end

      it 'returns checkpoints from every namespace when checkpoint_ns is omitted, unfiltered' do
        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to contain_exactly(top_level_checkpoint.id.first, nested_checkpoint.id.first)
      end
    end

    context 'with accept_compressed parameter' do
      it 'returns compressed checkpoints when accept_compressed is true' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user), params: { accept_compressed: true }, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:ok)

        compressed_data = json_response[0]['compressed_checkpoint']
        expect(compressed_data).to eq('eJyrVspOrVSyUipLzClNVaoFAChMBSE=')
        decompressed = ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
        expect(decompressed).to eq(checkpoint.checkpoint)
        expect(json_response[0]).not_to have_key('checkpoint')
      end

      it 'returns uncompressed checkpoints when accept_compressed is false' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user), params: { accept_compressed: false }, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response[0]['checkpoint']).to eq(checkpoint.checkpoint)
        expect(json_response[0]).not_to have_key('compressed_checkpoint')
      end

      it 'returns uncompressed checkpoints by default' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response[0]['checkpoint']).to eq(checkpoint.checkpoint)
      end
    end

    context 'when the workflow reconstructs checkpoints from blobs' do
      before do
        stub_feature_flags(dw_read_blobs_list: project)
      end

      def json_blob(channel:, version:, value:, thread_ts:, step_action: 'conversation')
        create(:duo_workflows_checkpoint_blob, workflow: workflow, thread_ts: thread_ts, channel: channel,
          version: version, write_type: 'json', step_action: step_action,
          data: Zlib::Deflate.deflate(::Gitlab::Json.dump(value)))
      end

      it 'serves headers with reconstructed channel_values, newest thread_ts first' do
        header1 = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1')
        header2 = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-2')
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'hi' }], thread_ts: 'ts-2')
        checkpoint_write = create(:duo_workflows_checkpoint_write, thread_ts: header2.thread_ts, workflow: workflow)

        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('thread_ts')).to eq([header2.thread_ts, header1.thread_ts])
        expect(json_response[0]['id']).to eq(header2.id.first)
        expect(json_response[0]['checkpoint']['channel_values']['ui_chat_log']).to eq([{ 'content' => 'hi' }])
        expect(json_response[0]['checkpoint_writes'][0]['id']).to eq(checkpoint_write.id)
      end

      # A header is written for every checkpoint whenever incremental checkpoints are
      # on, so a dual-written checkpoint has both rows. Serve the header: compaction
      # truncates the full row's ui_chat_log, and only the blobs keep the history.
      it 'serves the blob-reconstructed history for a checkpoint that also has a legacy row' do
        create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-shared',
          checkpoint: { 'channel_values' => { 'ui_chat_log' => [{ 'content' => 'truncated' }] } })
        header = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-shared')
        json_blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
          value: [{ 'content' => 'first' }], thread_ts: 'ts-shared')
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'second' }], thread_ts: 'ts-shared')

        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq([header.id.first])
        expect(json_response[0]['checkpoint']['channel_values']['ui_chat_log'])
          .to eq([{ 'content' => 'first' }, { 'content' => 'second' }])
      end

      it 'paginates in the database rather than loading every checkpoint' do
        5.times { |i| create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: "ts-#{i}") }

        get api(path, user), params: { per_page: 2, page: 1 }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('thread_ts')).to eq(%w[ts-4 ts-3])
        expect(response.headers['X-Total']).to eq('5')
        expect(response.headers['X-Per-Page']).to eq('2')
      end

      it 'applies checkpoint_ns filtering to header-only checkpoints too' do
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-top')
        nested_header = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-nested',
          checkpoint_ns: 'delegation:task-1')

        get api(path, user), params: { checkpoint_ns: 'delegation:task-1' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq([nested_header.id.first])
      end

      it 'rebuilds channel_values inside the compressed checkpoint when accept_compressed is true' do
        header = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-compressed')
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'hi' }], thread_ts: header.thread_ts)

        get api(path, user), params: { accept_compressed: true }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        decompressed = ::Gitlab::Json.parse(
          Zlib::Inflate.inflate(Base64.strict_decode64(json_response[0]['compressed_checkpoint']))
        )
        expect(decompressed['channel_values']['ui_chat_log']).to eq([{ 'content' => 'hi' }])
        expect(json_response[0]).not_to have_key('checkpoint')
      end

      it 'loads the page blobs in a single query rather than one per checkpoint' do
        # A linear chain, so every checkpoint's ancestor chain overlaps the others:
        # the per-checkpoint version issued one blob query each over the same rows.
        parent = nil
        9.times do |i|
          create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: "ts-#{i}", parent_ts: parent)
          json_blob(channel: 'ui_chat_log', version: (i + 1).to_s, value: [{ 'content' => "m#{i}" }],
            thread_ts: "ts-#{i}")
          parent = "ts-#{i}"
        end

        recorder = ActiveRecord::QueryRecorder.new { get api(path, user), headers: workhorse_headers }

        blob_queries = recorder.log.count { |query| query.include?('p_duo_workflows_checkpoint_blobs') }
        expect(blob_queries).to eq(1)
      end

      it 'folds each checkpoint against only its own ancestor chain when batched' do
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c1', parent_ts: nil)
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c2', parent_ts: 'c1')
        json_blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
          value: [{ 'content' => 'm1' }], thread_ts: 'c1')
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'm2' }], thread_ts: 'c2')

        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        by_ts = json_response.index_by { |cp| cp['thread_ts'] }
        # c2 sees its ancestor c1's blob; c1 must not see its descendant's.
        expect(by_ts['c2']['checkpoint']['channel_values']['ui_chat_log'])
          .to eq([{ 'content' => 'm1' }, { 'content' => 'm2' }])
        expect(by_ts['c1']['checkpoint']['channel_values']['ui_chat_log']).to eq([{ 'content' => 'm1' }])
      end

      it 'batches checkpoint_writes into a single query regardless of the number of header-only checkpoints' do
        # accumulated_blobs_for still runs once per checkpoint (an accepted,
        # pre-existing cost shared with GraphQL's per-checkpoint reconstruction) --
        # this only asserts the checkpoint_writes half stays batched.
        9.times { |i| create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: "ts-#{i}") }

        recorder = ActiveRecord::QueryRecorder.new { get api(path, user), headers: workhorse_headers }

        writes_queries = recorder.log.count { |query| query.include?('duo_workflows_checkpoint_writes') }
        expect(writes_queries).to eq(1)
      end

      context 'when dw_read_blobs_list is off' do
        before do
          stub_feature_flags(dw_read_blobs_list: false)
        end

        it 'keeps serving only the legacy table, ignoring header-only checkpoints' do
          legacy = create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-legacy')
          create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-header-only')

          get api(path, user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to eq([legacy.id.first])
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints/:checkpoint_id' do
    it 'returns the checkpoint' do
      checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint_write = create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
        workflow: checkpoint.workflow)
      path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

      get api(path, user), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(checkpoint.id.first)
      expect(json_response['thread_ts']).to eq(checkpoint.thread_ts)
      expect(json_response['parent_ts']).to eq(checkpoint.parent_ts)
      expect(json_response).to have_key('checkpoint')
      expect(json_response).to have_key('metadata')
      expect(json_response['checkpoint_writes'][0]['id']).to eq(checkpoint_write.id)
      expect(json_response).not_to have_key('compressed_checkpoint')
    end

    it "fails when request doesn't have workhorse headers" do
      checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
      create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
        workflow: checkpoint.workflow)
      path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

      get api(path, user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when a checkpoint from a workflow belongs to a different user' do
      it 'returns 404' do
        workflow = create(:duo_workflows_workflow, project: project)
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
          workflow: checkpoint.workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"
        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with accept_compressed parameter' do
      it 'returns compressed checkpoint when accept_compressed is true' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts, workflow: checkpoint.workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

        get api(path, user), params: { accept_compressed: true }, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:ok)

        compressed_data = json_response['compressed_checkpoint']
        decompressed = ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
        expect(decompressed).to eq(checkpoint.checkpoint)
        expect(json_response['checkpoint_writes']).to be_present
        expect(json_response).not_to have_key('checkpoint')
      end

      it 'returns uncompressed checkpoint when accept_compressed is false' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

        get api(path, user), params: { accept_compressed: false }, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['checkpoint']).to eq(checkpoint.checkpoint)
        expect(json_response).not_to have_key('compressed_checkpoint')
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints/by_thread_ts' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/by_thread_ts" }

    def json_blob(channel:, version:, value:, thread_ts:, step_action: 'conversation', current_thread: 0)
      create(:duo_workflows_checkpoint_blob, workflow: workflow, current_thread: current_thread,
        thread_ts: thread_ts, channel: channel, version: version, write_type: 'json',
        step_action: step_action, data: Zlib::Deflate.deflate(::Gitlab::Json.dump(value)))
    end

    it "fails when request doesn't have workhorse headers" do
      get api(path, user), params: { thread_ts: 'ts-1' }

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when a header exists for the thread_ts' do
      it 'folds a channel across the ancestor chain onto the slim header' do
        # Each checkpoint writes one blob per changed channel (the gateway emits one
        # version per channel per step), so the ui_chat_log deltas span two
        # checkpoints in the group; reconstruction folds them oldest-first.
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1',
          current_thread: 0, parent_ts: nil)
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'one' }], thread_ts: 'ts-1')

        header = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-2',
          current_thread: 0, parent_ts: 'ts-1', checkpoint: { 'v' => 1, 'channel_versions' => {} })
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'two' }], thread_ts: 'ts-2')
        checkpoint_write = create(:duo_workflows_checkpoint_write, thread_ts: 'ts-2', workflow: workflow)

        get api(path, user), params: { thread_ts: 'ts-2' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(header.id.first)
        expect(json_response['thread_ts']).to eq('ts-2')
        expect(json_response['checkpoint']['v']).to eq(1)
        expect(json_response['checkpoint']['channel_values']['ui_chat_log'])
          .to eq([{ 'content' => 'one' }, { 'content' => 'two' }])
        expect(json_response['checkpoint_writes'][0]['id']).to eq(checkpoint_write.id)
      end

      it 'rebuilds channel_values inside the compressed checkpoint when accept_compressed is true' do
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1', current_thread: 0)
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'one' }], thread_ts: 'ts-1')

        get api(path, user), params: { thread_ts: 'ts-1', accept_compressed: true }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        decompressed = ::Gitlab::Json.parse(
          Zlib::Inflate.inflate(Base64.strict_decode64(json_response['compressed_checkpoint']))
        )
        expect(decompressed['channel_values']['ui_chat_log']).to eq([{ 'content' => 'one' }])
        expect(json_response).not_to have_key('checkpoint')
      end

      it 'excludes blobs from a prior current_thread group' do
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-new', current_thread: 1)
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'old' }],
          thread_ts: 'ts-old', current_thread: 0)
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'current' }],
          thread_ts: 'ts-new', current_thread: 1)

        get api(path, user), params: { thread_ts: 'ts-new' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['checkpoint']['channel_values']['ui_chat_log']).to eq([{ 'content' => 'current' }])
      end

      it 'reconstructs only the requested branch when a fork shares the current_thread group' do
        # ai-assist#2440 stop/retry: c1 forks into c2->c3 and c6->c7, all one group.
        # c1 opens the group with a full compaction snapshot; each step appends one.
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c1', parent_ts: nil)
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c2', parent_ts: 'c1')
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c3', parent_ts: 'c2')
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c6', parent_ts: 'c1')
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'c7', parent_ts: 'c6')

        json_blob(channel: 'ui_chat_log', version: '1', step_action: 'compaction',
          value: [{ 'content' => 'm1' }], thread_ts: 'c1')
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'm2' }], thread_ts: 'c2')
        json_blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'm3' }], thread_ts: 'c3')
        json_blob(channel: 'ui_chat_log', version: '2', value: [{ 'content' => 'm6' }], thread_ts: 'c6')
        json_blob(channel: 'ui_chat_log', version: '3', value: [{ 'content' => 'm7' }], thread_ts: 'c7')

        get api(path, user), params: { thread_ts: 'c7' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['checkpoint']['channel_values']['ui_chat_log'])
          .to eq([{ 'content' => 'm1' }, { 'content' => 'm6' }, { 'content' => 'm7' }])
      end

      it 'returns 404 when no header matches the thread_ts' do
        get api(path, user), params: { thread_ts: 'missing' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when both read feature flags are off' do
      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: false, dw_read_blobs_api: false)
      end

      it 'still serves the reconstructed checkpoint because the gateway owns the read decision' do
        create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1', current_thread: 0)
        json_blob(channel: 'ui_chat_log', version: '1', value: [{ 'content' => 'one' }], thread_ts: 'ts-1')

        get api(path, user), params: { thread_ts: 'ts-1' }, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['checkpoint']['channel_values']['ui_chat_log']).to eq([{ 'content' => 'one' }])
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoint_writes_batch' do
    let(:params) do
      {
        thread_ts: 'checkpoint_id',
        checkpoint_writes: [task: 'id', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
      }
    end

    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoint_writes_batch" }

    it 'allows updating a workflow' do
      post api(path, user), params: params, headers: workhorse_headers

      expect(response).to have_gitlab_http_status(:success)
    end

    it "fails when request doesn't have workhorse headers" do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'with namespace-level chat workflow' do
      let(:workflow_definition) { 'chat' }
      let(:container_params) { { namespace_id: group.id } }

      it 'allows updating a workflow' do
        expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with invalid input' do
      let(:params) do
        {
          thread_ts: 'checkpoint_id',
          checkpoint_writes: [task: '', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
        }
      end

      it 'returns bad request' do
        post api(path, user), params: params, headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to eq({ message: "400 Bad request - Validation failed: Task can't be blank" }.to_json)
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }
    let(:correlation_id) { nil }
    let(:params) do
      {
        event_type: 'message',
        message: 'Hello, World!',
        correlation_id: correlation_id
      }
    end

    context 'when success' do
      it 'creates a new event' do
        expect do
          post api(path, user), params: params, headers: workhorse_headers
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.events.count }.by(1)

        created_event = Ai::DuoWorkflows::Event.last
        expect(json_response['id']).to eq(created_event.id)
        expect(json_response['event_type']).to eq('message')
        expect(json_response['message']).to eq('Hello, World!')
        expect(json_response['event_status']).to eq('queued')
        expect(created_event.project_id).to eq(project.id)
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params, headers: workhorse_headers
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
        end

        it "fails when creating an event for another user's remote execution workflow" do
          other_user = create(:user, maintainer_of: project)
          other_workflow = create(:duo_workflows_workflow, user: other_user, project: project, environment: :web,
            workflow_definition: :convert_to_gitlab_ci)
          event_path = "/ai/duo_workflows/workflows/#{other_workflow.id}/events"

          post api(event_path, oauth_access_token: ai_workflows_oauth_token), params: params, headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when correlation_id is provided' do
        let(:correlation_id) { '123e4567-e89b-12d3-a456-426614174000' }

        it 'creates an event with the provided correlation_id' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params, headers: workhorse_headers
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
          expect(json_response['correlation_id']).to eq(correlation_id)
        end
      end

      context 'with namespace-level chat workflow' do
        let(:workflow_definition) { 'chat' }
        let(:container_params) { { namespace_id: group.id } }

        it 'allows updating a workflow' do
          expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

          post api(path, user), params: params, headers: workhorse_headers

          created_event = Ai::DuoWorkflows::Event.last
          expect(created_event.namespace_id).to eq(group.id)
        end
      end

      context 'when an invalid correlation_id is provided' do
        let(:correlation_id) { 'invalid_id' }

        it 'rejects an invalid correlation_id' do
          post api(path, user), params: params, headers: workhorse_headers
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('correlation_id is invalid')
        end
      end
    end

    context 'when required parameters are missing' do
      it 'returns bad request when event_type is missing' do
        post api(path, user), params: params.except(:event_type), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type is missing")
      end

      it 'returns bad request when message is missing' do
        post api(path, user), params: params.except(:message), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("message is missing")
      end
    end

    context 'when invalid event_type is provided' do
      it 'returns bad request' do
        post api(path, user), params: params.merge(event_type: 'invalid_event_type'), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type does not have a valid value")
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params, headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }

    it 'returns queued events for the workflow' do
      event1 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)
      event2 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)

      get api(path, user), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.size).to eq(2)
      expect(json_response.map { |e| e['id'] }).to contain_exactly(event1.id, event2.id)
      expect(json_response.map { |e| e['event_status'] }).to all(eq('queued'))
    end

    it 'returns empty array if no queued events' do
      create(:duo_workflows_event, workflow: workflow, event_status: :delivered)

      get api(path, user), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_empty
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /ai/duo_workflows/workflows/:id/events/:event_id' do
    let(:event) { create(:duo_workflows_event, workflow: workflow, event_status: :queued) }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/#{event.id}" }
    let(:params) { { event_status: 'delivered' } }

    context 'when success' do
      it 'updates the event status' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(event.id)
        expect(json_response['event_status']).to eq('delivered')
        expect(event.reload.event_status).to eq('delivered')
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          put api(path, oauth_access_token: ai_workflows_oauth_token), params: params
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when invalid event_status is provided' do
      it 'returns bad request' do
        put api(path, user), params: { event_status: 'InvalidStatus' }
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_status does not have a valid value")
      end
    end

    context 'when the event does not exist' do
      let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/0" }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with an event belonging to a different workflow' do
      let(:other_workflow) { create(:duo_workflows_workflow, user: user, project: project) }
      let(:event) { create(:duo_workflows_event, workflow: other_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    before do
      allow(Gitlab::AiGateway)
        .to receive(:public_headers)
        .with(hash_including(user: user, ai_feature_name: :duo_workflow,
          unit_primitive_name: :duo_workflow_execute_workflow))
        .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
    end

    it 'returns the Ai::DuoWorkflows::Workflow' do
      get api(path, user), headers: workhorse_headers

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(workflow.id)
      expect(json_response['project_id']).to eq(project.id)
      expect(json_response['agent_privileges']).to eq(workflow.agent_privileges)
      expect(json_response['agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['pre_approved_agent_privileges']).to eq(workflow.pre_approved_agent_privileges)
      expect(json_response['pre_approved_agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['allow_agent_to_request_user']).to be(true)
      expect(json_response['mcp_enabled']).to be(true)
      expect(json_response['incremental_checkpoints_enabled']).to be(true)
      expect(json_response['gitlab_url']).to eq(Gitlab.config.gitlab.url)
      expect(json_response['status']).to eq("created")
      expect(json_response['summary']).to eq(workflow.summary)
      expect(json_response['title']).to eq(workflow.title)
      expect(json_response['ai_catalog_item_version_id']).to eq(ai_catalog_item_version.id)
      expect(response.headers['X-Gitlab-Enabled-Feature-Flags']).to include('test-feature')
    end

    it "fails when request doesn't have workhorse headers" do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: ai_workflows_oauth_token), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when authenticated with a composite identity token' do
      let(:service_account) do
        create(:user, :service_account, developer_of: workflow.project, composite_identity_enforced: true)
      end

      let(:composite_oauth_token) do
        create(:oauth_access_token, user: service_account, scopes: ['ai_workflows', "user:#{user.id}"])
      end

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(hash_including(user: service_account, ai_feature_name: :duo_workflow,
            unit_primitive_name: :duo_workflow_execute_workflow))
          .and_return({})
      end

      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: composite_oauth_token), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        get api(path, user), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user), headers: workhorse_headers
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    context 'when update workflow status service returns error' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(reason: :bad_request,
            message: 'Cannot update workflow status'))
        end
      end

      it 'returns http error status and error message' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Cannot update workflow status')
      end
    end

    context 'when update workflow status service returns success' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { workflow: workflow },
            message: 'Workflow status updated'))
        end
      end

      it 'returns http status ok' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['workflow']['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /ai/duo_workflows/revoke_token' do
    let(:path) { "/ai/duo_workflows/revoke_token" }

    context 'when service returns an error with :invalid_token_ownership reason' do
      it 'returns forbidden status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :invalid_token_ownership,
            message: 'Invalid token ownership'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Invalid token ownership')
      end
    end

    context 'when service returns an error with :insufficient_token_scope reason' do
      it 'returns forbidden status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :insufficient_token_scope,
            message: 'Insufficient token scope'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Insufficient token scope')
      end
    end

    context 'when service returns an error with :failed_to_revoke reason' do
      it 'returns unprocessable entity status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :failed_to_revoke,
            message: 'Could not revoke token'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Could not revoke token')
      end
    end

    context 'when service returns success' do
      it 'returns ok status with the response payload' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: {}, message: 'Token revoked'))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({})
      end
    end
  end
end
