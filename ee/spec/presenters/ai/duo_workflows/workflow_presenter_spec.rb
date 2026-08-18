# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::WorkflowPresenter, feature_category: :duo_agent_platform do
  let(:workflow) { build_stubbed(:duo_workflows_workflow) }
  let_it_be(:user) { build_stubbed(:user) }

  subject(:presenter) { described_class.new(workflow, current_user: user) }

  describe 'human_status' do
    it 'returns the human readable status' do
      expect(presenter.human_status).to eq("created")
    end
  end

  describe '#web_url' do
    it 'delegates to the workflow' do
      allow(workflow).to receive(:web_url).and_return('https://gitlab.example.com/group/project/-/automate/agent-sessions/1')

      expect(presenter.web_url).to eq('https://gitlab.example.com/group/project/-/automate/agent-sessions/1')
    end
  end

  describe 'mcp_enabled' do
    let_it_be(:ai_settings) { build_stubbed(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }

    it 'returns the mcp_enabled status from the root ancestor' do
      root_ancestor = instance_double(Group, duo_workflow_mcp_enabled: true)
      allow(workflow.project).to receive(:root_ancestor).and_return(root_ancestor)

      expect(presenter.mcp_enabled).to be(true)
    end

    context 'with namespace-level workflow' do
      let(:group) { build_stubbed(:group) }
      let(:workflow) { build_stubbed(:duo_workflows_workflow, namespace: group, project: nil) }

      it { expect(presenter.mcp_enabled).to be(false) }

      context 'when duo_workflow_mcp_enabled is enabled on root ancestor' do
        before do
          root_ancestor = instance_double(Group, duo_workflow_mcp_enabled: true)
          allow(workflow.namespace).to receive(:root_ancestor).and_return(root_ancestor)
        end

        it { expect(presenter.mcp_enabled).to be(true) }
      end
    end
  end

  describe 'agent_privileges_names' do
    it 'returns the agent privileges names' do
      allow(workflow).to receive(:agent_privileges).and_return([
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES
      ])

      expect(presenter.agent_privileges_names).to eq(['read_write_files'])
    end
  end

  describe 'pre_approved_agent_privileges_names' do
    it 'returns the pre-approved agent privileges names' do
      allow(workflow).to receive(:pre_approved_agent_privileges).and_return([
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS
      ])

      expect(presenter.pre_approved_agent_privileges_names).to eq(%w[read_write_files run_commands])
    end
  end

  # Persisted records are required: first_checkpoint/latest_checkpoint run real
  # queries over workflow.checkpoints/checkpoint_headers, so build_stubbed won't do.
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- see above
  describe 'first_checkpoint' do
    # Checkpoint/CheckpointHeader have a composite [id, created_at]/[id, workflow_created_at]
    # primary key (partitioning), so comparing full records is sensitive to timestamp
    # precision (in-memory ns vs DB us) -- compare the scalar id instead, matching the
    # convention already used for this in workflow_spec.rb.
    subject(:first_checkpoint_id) { presenter.first_checkpoint(checkpoint_ns: checkpoint_ns)&.id&.first }

    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }
    let(:checkpoint_ns) { nil }

    context 'when the workflow has checkpoints' do
      let_it_be(:earliest) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1') }
      let_it_be(:newer) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-2') }

      it { is_expected.to eq(earliest.id.first) }

      context 'with a checkpoint_ns' do
        let_it_be(:nested) do
          create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-0', checkpoint_ns: 'delegation:task-1')
        end

        let(:checkpoint_ns) { 'delegation:task-1' }

        it { is_expected.to eq(nested.id.first) }
      end
    end

    context 'when the workflow has no checkpoints' do
      it { is_expected.to be_nil }
    end

    context 'when the workflow reconstructs checkpoints from blobs' do
      let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: true) }
      let_it_be(:legacy_checkpoint) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1') }
      let_it_be(:earliest_header) { create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-0') }

      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: workflow.project,
          dw_read_blobs_graphql: workflow.project)
      end

      it 'returns the earliest checkpoint header instead of reading the legacy table' do
        expect(first_checkpoint_id).to eq(earliest_header.id.first)
      end

      context 'with a checkpoint_ns' do
        let_it_be(:nested_header) do
          create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-2',
            checkpoint_ns: 'delegation:task-1')
        end

        let(:checkpoint_ns) { 'delegation:task-1' }

        it { is_expected.to eq(nested_header.id.first) }
      end
    end
  end

  describe 'latest_checkpoint' do
    # See the comment on first_checkpoint's subject: compare scalar ids, not full records.
    subject(:latest_checkpoint_id) { presenter.latest_checkpoint(checkpoint_ns: checkpoint_ns)&.id&.first }

    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }
    let(:checkpoint_ns) { nil }

    context 'when the workflow has checkpoints' do
      let_it_be(:older) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1') }
      let_it_be(:latest) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-2') }

      it { is_expected.to eq(latest.id.first) }

      context 'with a checkpoint_ns' do
        let_it_be(:nested) do
          create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-3', checkpoint_ns: 'delegation:task-1')
        end

        let(:checkpoint_ns) { 'delegation:task-1' }

        it { is_expected.to eq(nested.id.first) }
      end
    end

    context 'when the workflow has no checkpoints' do
      it { is_expected.to be_nil }
    end

    context 'when the workflow reconstructs checkpoints from blobs' do
      let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, incremental_checkpoints_enabled: true) }
      let_it_be(:legacy_checkpoint) { create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1') }
      let_it_be(:latest_header) { create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-2') }

      before do
        stub_feature_flags(duo_workflow_read_incremental_checkpoints: workflow.project,
          dw_read_blobs_graphql: workflow.project)
      end

      it 'returns the latest checkpoint header instead of reading the legacy table' do
        expect(latest_checkpoint_id).to eq(latest_header.id.first)
      end

      context 'with a checkpoint_ns' do
        let_it_be(:nested_header) do
          create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-3',
            checkpoint_ns: 'delegation:task-1')
        end

        let(:checkpoint_ns) { 'delegation:task-1' }

        it { is_expected.to eq(nested_header.id.first) }
      end
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  describe 'flow_metadata_version' do
    context 'when flow_metadata_json is set' do
      it 'returns the flow_version from the parsed JSON' do
        allow(workflow).to receive(:flow_metadata_json)
          .and_return('{"flow_version":"2.0.0","schema_version":"v1","flow_id":"developer"}')

        expect(presenter.flow_metadata_version).to eq('2.0.0')
      end
    end

    context 'when flow_metadata_json is blank' do
      it 'returns nil' do
        allow(workflow).to receive(:flow_metadata_json).and_return(nil)

        expect(presenter.flow_metadata_version).to be_nil
      end
    end
  end

  describe 'flow_metadata_id' do
    context 'when flow_metadata_json is set' do
      it 'returns the flow_id from the parsed JSON' do
        allow(workflow).to receive(:flow_metadata_json)
          .and_return('{"flow_version":"2.0.0","schema_version":"v1","flow_id":"developer"}')

        expect(presenter.flow_metadata_id).to eq('developer')
      end
    end

    context 'when flow_metadata_json is blank' do
      it 'returns nil' do
        allow(workflow).to receive(:flow_metadata_json).and_return(nil)

        expect(presenter.flow_metadata_id).to be_nil
      end
    end
  end

  describe 'flow_metadata_schema_version' do
    context 'when flow_metadata_json is set' do
      it 'returns the schema_version from the parsed JSON' do
        allow(workflow).to receive(:flow_metadata_json)
          .and_return('{"flow_version":"2.0.0","schema_version":"v1","flow_id":"developer"}')

        expect(presenter.flow_metadata_schema_version).to eq('v1')
      end
    end

    context 'when flow_metadata_json is blank' do
      it 'returns nil' do
        allow(workflow).to receive(:flow_metadata_json).and_return(nil)

        expect(presenter.flow_metadata_schema_version).to be_nil
      end
    end
  end

  describe 'agent_name' do
    context 'when workflow uses a custom catalog agent' do
      it 'returns the catalog item name' do
        catalog_item = instance_double(Ai::Catalog::Item, name: 'Custom Agent')
        catalog_item_version = instance_double(Ai::Catalog::ItemVersion, item: catalog_item)
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: 123,
          ai_catalog_item_version: catalog_item_version
        )

        expect(presenter.agent_name).to eq('Custom Agent')
      end
    end

    context 'when workflow uses a foundational agent' do
      it 'returns the foundational agent name' do
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: nil,
          workflow_definition: 'chat'
        )

        expect(presenter.agent_name).to eq('GitLab Duo')
      end
    end

    context 'when workflow has no agent information' do
      it 'returns nil' do
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: nil,
          workflow_definition: nil
        )

        expect(presenter.agent_name).to be_nil
      end
    end
  end
end
