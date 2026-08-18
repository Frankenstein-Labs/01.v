# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEvent, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:cloud_event_id) { SecureRandom.uuid }
  let(:valid_attrs) do
    {
      cloud_event_id: cloud_event_id,
      event_name: 'ai_llm_input_sent',
      author_id: user.id,
      project_id: project.id,
      workflow_id: 42,
      ip_address: '127.0.0.1',
      details: { model: 'claude-3' }
    }
  end

  subject(:event) { described_class.new(valid_attrs) }

  describe 'table configuration' do
    it 'uses the ai_audit_events table' do
      expect(described_class.table_name).to eq('ai_audit_events')
    end

    it 'uses id as the Rails-level primary key' do
      expect(described_class.primary_key).to eq('id')
    end
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:cloud_event_id) }
    it { is_expected.to validate_presence_of(:event_name) }
    it { is_expected.to validate_presence_of(:author_id) }
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe 'scopes' do
    let_it_be(:workflow_id_1) { 100 }
    let_it_be(:workflow_id_2) { 200 }
    let_it_be(:event_for_workflow_1_first) do
      create(:audit_events_ai_audit_event, target_project: project, workflow_id: workflow_id_1)
    end

    let_it_be(:event_for_workflow_1_second) do
      create(:audit_events_ai_audit_event, target_project: project, workflow_id: workflow_id_1)
    end

    let_it_be(:event_for_workflow_2) do
      create(:audit_events_ai_audit_event, target_project: project, workflow_id: workflow_id_2)
    end

    describe '.for_workflow' do
      it 'returns only events for the given workflow_id' do
        expect(described_class.for_workflow(workflow_id_1))
          .to contain_exactly(event_for_workflow_1_first, event_for_workflow_1_second)
      end

      it 'returns an empty relation when no events match' do
        expect(described_class.for_workflow(non_existing_record_id)).to be_empty
      end
    end

    describe '.recent_first' do
      it 'orders by id descending' do
        ids = described_class.for_workflow(workflow_id_1).recent_first.pluck(:id)

        expect(ids).to eq(ids.sort.reverse)
      end
    end
  end

  describe 'persistence' do
    it 'saves to PostgreSQL' do
      event.save!
      expect(described_class.find_by(id: event.id, created_at: event.created_at)).to be_present
    end

    it 'serializes details as Hash' do
      event.details = { session_id: 'test-123' }
      event.save!

      reloaded = described_class.find_by(id: event.id, created_at: event.created_at)
      expect(reloaded.details).to eq({ session_id: 'test-123' })
    end
  end

  describe 'bulk insert' do
    it 'supports bulk_insert!' do
      events = Array.new(3) do
        build(:audit_events_ai_audit_event, user: user, target_project: project)
      end

      expect { described_class.bulk_insert!(events, returns: :ids) }.to change { described_class.count }.by(3)
    end
  end

  describe '#store_to_clickhouse' do
    it 'adds a row to the ClickHouse write buffer' do
      expect(ClickHouse::WriteBuffer).to receive(:add).with('ai_audit_events', anything)
      event.store_to_clickhouse
    end

    it 'returns false and does not write when invalid' do
      event.event_name = nil
      expect(ClickHouse::WriteBuffer).not_to receive(:add)
      expect(event.store_to_clickhouse).to be(false)
    end
  end

  describe '#to_clickhouse_csv_row' do
    subject(:row) { event.to_clickhouse_csv_row }

    it 'returns a hash with all expected keys' do
      expect(row.keys).to contain_exactly(
        :id, :event_name, :created_at, :author_id, :project_id,
        :group_id, :ip_address, :workflow_id, :details
      )
    end

    it 'uses cloud_event_id as the ClickHouse id' do
      expect(row[:id]).to eq(cloud_event_id)
    end

    it 'maps namespace_id to group_id for ClickHouse' do
      expect(row[:group_id]).to eq(event.namespace_id)
    end

    it 'serializes details hash to JSON' do
      expect(row[:details]).to eq('{"model":"claude-3"}')
    end

    it 'serializes nil details as empty JSON object' do
      event.details = nil
      expect(event.to_clickhouse_csv_row[:details]).to eq('{}')
    end

    it 'converts nil ip_address to empty string' do
      event.ip_address = nil
      expect(row[:ip_address]).to eq('')
    end

    it 'rounds created_at to 3 decimal places' do
      event.created_at = Time.zone.at(1_000_000.123456)
      expect(row[:created_at]).to eq(1_000_000.123)
    end
  end

  describe 'CLICKHOUSE_TABLE_NAME' do
    it 'returns ai_audit_events' do
      expect(described_class::CLICKHOUSE_TABLE_NAME).to eq('ai_audit_events')
    end
  end

  describe 'ALLOWED_EVENT_NAMES' do
    it 'is frozen and non-empty' do
      expect(described_class::ALLOWED_EVENT_NAMES).to be_frozen
      expect(described_class::ALLOWED_EVENT_NAMES).not_to be_empty
    end

    it 'contains no duplicates' do
      names = described_class::ALLOWED_EVENT_NAMES
      expect(names.uniq).to eq(names)
    end

    it 'every entry is a registered Gitlab::Audit::Type::Definition' do
      missing = described_class::ALLOWED_EVENT_NAMES.reject do |name|
        Gitlab::Audit::Type::Definition.defined?(name)
      end

      expect(missing).to be_empty,
        "Names in ALLOWED_EVENT_NAMES without a YAML definition under " \
          "(ee/)config/audit_events/types/: #{missing.inspect}. " \
          "Either add the YAML or remove from the constant."
    end
  end

  describe '#as_json' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:ai_audit_event) do
      create(:audit_events_ai_audit_event, target_project: project, workflow_id: workflow.id)
    end

    it 'includes derived top-level fields for streaming', :aggregate_failures do
      json = ai_audit_event.as_json

      expect(json['id']).to eq(ai_audit_event.cloud_event_id)
      expect(json['target_id']).to eq(workflow.id)
      expect(json['target_type']).to eq('Ai::DuoWorkflows::Workflow')
      expect(json['target_details']).to eq("#{workflow.workflow_definition} session #{workflow.id}")
      expect(json['entity_id']).to eq(project.id)
      expect(json['entity_type']).to eq('Project')
      expect(json['entity_path']).to eq(project.full_path)
      expect(json['author_name']).to be_present
    end

    it 'emits cloud_event_id as the streamed `id` even for unsaved records' do
      unsaved = build(:audit_events_ai_audit_event, target_project: project, workflow_id: workflow.id)

      expect(unsaved.id).to be_nil
      expect(unsaved.as_json['id']).to eq(unsaved.cloud_event_id)
    end

    it 'mirrors canonical audit metadata into details', :aggregate_failures do
      details = ai_audit_event.as_json['details']

      expect(details).to include(
        'event_name' => ai_audit_event.event_name,
        'author_class' => 'User',
        'target_id' => workflow.id,
        'target_type' => 'Ai::DuoWorkflows::Workflow',
        'target_details' => "#{workflow.workflow_definition} session #{workflow.id}",
        'ip_address' => ai_audit_event.ip_address.to_s,
        'entity_path' => project.full_path
      )
      expect(details['author_name']).to be_present
    end

    it 'falls back to "Unknown" when the workflow record is missing' do
      orphan = build(:audit_events_ai_audit_event, target_project: project,
        workflow_id: non_existing_record_id)

      expect(orphan.as_json['target_details']).to eq("Unknown session #{non_existing_record_id}")
    end

    it 'preserves existing details payload alongside canonical metadata' do
      expect(ai_audit_event.as_json['details']).to include(
        'session_id' => 'session-abc123',
        'agent_id' => 'duo-workflow'
      )
    end

    context 'when only namespace_id is set (group-scoped event)' do
      let_it_be(:ns_group) { create(:group) }
      let_it_be(:group_workflow) { create(:duo_workflows_workflow, project: project) }
      let(:group_event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: ns_group.id,
          workflow_id: group_workflow.id))
      end

      it 'reports Group entity in top-level fields', :aggregate_failures do
        json = group_event.as_json

        expect(json['entity_id']).to eq(ns_group.id)
        expect(json['entity_type']).to eq('Group')
        expect(json['entity_path']).to eq(ns_group.full_path)
      end

      it 'still reports the workflow as the target', :aggregate_failures do
        json = group_event.as_json

        expect(json['target_id']).to eq(group_workflow.id)
        expect(json['target_type']).to eq('Ai::DuoWorkflows::Workflow')
        expect(json['target_details']).to eq(
          "#{group_workflow.workflow_definition} session #{group_workflow.id}"
        )
      end

      it 'mirrors group entity_path into details', :aggregate_failures do
        details = group_event.as_json['details']

        expect(details).to include(
          'target_type' => 'Ai::DuoWorkflows::Workflow',
          'entity_path' => ns_group.full_path
        )
      end
    end
  end

  describe '#entity' do
    context 'when project_id is set' do
      let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project) }

      it 'returns the project' do
        expect(ai_audit_event.entity).to eq(project)
      end
    end

    context 'when only namespace_id is set' do
      let_it_be(:ns_group) { create(:group) }
      let(:ai_audit_event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: ns_group.id))
      end

      it 'returns the group' do
        expect(ai_audit_event.entity).to eq(ns_group)
      end
    end

    context 'when both project_id and namespace_id are blank' do
      let(:ai_audit_event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: nil))
      end

      it 'returns a NullEntity' do
        expect(ai_audit_event.entity).to be_a(::Gitlab::Audit::NullEntity)
      end
    end
  end

  describe '#entity_type' do
    context 'when project_id is set' do
      it 'returns Project' do
        expect(event.entity_type).to eq('Project')
      end
    end

    context 'when only namespace_id is set' do
      let(:event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: 1))
      end

      it 'returns Group' do
        expect(event.entity_type).to eq('Group')
      end
    end

    context 'when both project_id and namespace_id are blank' do
      let(:event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: nil))
      end

      it 'returns nil' do
        expect(event.entity_type).to be_nil
      end
    end
  end

  describe '#entity_id' do
    context 'when project_id is set' do
      let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project) }

      it 'returns the project id' do
        expect(ai_audit_event.entity_id).to eq(project.id)
      end
    end

    context 'when only namespace_id is set' do
      let_it_be(:ns_group) { create(:group) }
      let(:ai_audit_event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: ns_group.id))
      end

      it 'returns the group id' do
        expect(ai_audit_event.entity_id).to eq(ns_group.id)
      end
    end
  end

  describe '#root_group_entity' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }

    context 'when namespace_id points to a subgroup' do
      let(:event) do
        described_class.new(valid_attrs.merge(namespace_id: subgroup.id, project_id: nil))
      end

      it 'returns the root ancestor group' do
        expect(event.root_group_entity).to eq(root_group)
      end

      it 'memoizes root_group_entity_id' do
        event.root_group_entity
        expect(event.root_group_entity_id).to eq(root_group.id)
      end
    end

    context 'when namespace_id is blank but project belongs to a subgroup' do
      let(:event) do
        described_class.new(valid_attrs.merge(namespace_id: nil, project_id: project_in_subgroup.id))
      end

      it 'resolves the root ancestor through the project group' do
        expect(event.root_group_entity).to eq(root_group)
      end
    end

    context 'when both namespace_id and project_id are blank' do
      let(:event) do
        described_class.new(valid_attrs.merge(namespace_id: nil, project_id: nil))
      end

      it 'returns nil' do
        expect(event.root_group_entity).to be_nil
      end
    end

    context 'when root_group_entity_id is preset' do
      let(:event) do
        described_class.new(valid_attrs).tap { |e| e.root_group_entity_id = root_group.id }
      end

      it 'returns the cached group without re-resolving' do
        expect(::Group).to receive(:find_by).with(id: root_group.id).and_call_original
        expect(event.root_group_entity).to eq(root_group)
      end
    end
  end

  describe '#streamable_namespace' do
    let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project) }

    it 'returns the project namespace when entity is a project' do
      expect(ai_audit_event.streamable_namespace).to eq(project.project_namespace)
    end

    context 'when only namespace_id is set' do
      let_it_be(:ns_group) { create(:group) }
      let(:event) do
        described_class.new(valid_attrs.merge(project_id: nil, namespace_id: ns_group.id))
      end

      it 'returns the group itself' do
        expect(event.streamable_namespace).to eq(ns_group)
      end
    end

    context 'when both project_id and namespace_id are blank' do
      let(:event) { described_class.new(valid_attrs.merge(project_id: nil, namespace_id: nil)) }

      it 'returns nil' do
        expect(event.streamable_namespace).to be_nil
      end
    end
  end

  describe '#streaming_json' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:project_in_root_group) { create(:project, group: root_group) }
    let_it_be(:ai_audit_event) do
      create(:audit_events_ai_audit_event, target_project: project_in_root_group)
    end

    subject(:parsed) { ::Gitlab::Json.safe_parse(ai_audit_event.streaming_json) }

    it 'is valid JSON containing canonical streaming keys', :aggregate_failures do
      expect(parsed).to include(
        'id' => ai_audit_event.cloud_event_id,
        'event_name' => ai_audit_event.event_name,
        'project_id' => project_in_root_group.id,
        'namespace_id' => ai_audit_event.namespace_id,
        'entity_id' => project_in_root_group.id,
        'entity_type' => 'Project',
        'target_id' => ai_audit_event.workflow_id,
        'target_type' => 'Ai::DuoWorkflows::Workflow',
        'root_group_entity_id' => root_group.id
      )
    end

    it 'includes the cloud_event_id' do
      expect(parsed['cloud_event_id']).to eq(ai_audit_event.cloud_event_id)
    end
  end

  context 'with loose foreign key on ai_audit_events.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) do
        create(:audit_events_ai_audit_event, namespace_id: parent.id, project_id: nil, target_project: nil)
      end
    end
  end

  context 'with loose foreign key on ai_audit_events.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:audit_events_ai_audit_event, target_project: parent) }
    end
  end

  describe '.counts_for_workflows' do
    let_it_be(:workflow_1) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:workflow_2) { create(:duo_workflows_workflow, project: project) }

    before_all do
      create_list(:audit_events_ai_audit_event, 3, target_project: project, workflow_id: workflow_1.id)
      create_list(:audit_events_ai_audit_event, 2, target_project: project, workflow_id: workflow_2.id)
    end

    it 'returns a hash of workflow_id to event count' do
      counts = described_class.counts_for_workflows([workflow_1.id, workflow_2.id])

      expect(counts[workflow_1.id]).to eq(3)
      expect(counts[workflow_2.id]).to eq(2)
    end

    it 'returns an empty hash when no workflow_ids match' do
      expect(described_class.counts_for_workflows([non_existing_record_id])).to be_empty
    end

    it 'omits workflow_ids with no events rather than returning zero' do
      counts = described_class.counts_for_workflows([workflow_1.id, non_existing_record_id])

      expect(counts.key?(non_existing_record_id)).to be(false)
    end
  end
end
