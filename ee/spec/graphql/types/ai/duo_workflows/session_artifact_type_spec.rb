# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::SessionArtifactType, feature_category: :duo_agent_platform do
  it 'has the expected fields' do
    expected_fields = %i[
      id workflow_definition web_path download_path audit_events_count audit_events project workflow_created_at
      triggered_by
    ]
    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'exposes id as non-null GraphQL ID' do
    expect(described_class.fields['id'].type.to_type_signature).to eq('ID!')
  end

  it 'exposes workflowDefinition as non-null String' do
    expect(described_class.fields['workflowDefinition'].type.to_type_signature).to eq('String!')
  end

  it 'exposes workflowCreatedAt as non-null Time' do
    expect(described_class.fields['workflowCreatedAt'].type.to_type_signature).to eq('Time!')
  end

  it 'exposes auditEventsCount as non-null Int' do
    expect(described_class.fields['auditEventsCount'].type.to_type_signature).to eq('Int!')
  end

  it 'exposes webPath as nullable String' do
    expect(described_class.fields['webPath'].type.to_type_signature).to eq('String')
  end

  it 'exposes downloadPath as nullable String' do
    expect(described_class.fields['downloadPath'].type.to_type_signature).to eq('String')
  end

  describe '#id' do
    it 'returns the workflow_id as a Workflow GID' do
      artifact = instance_double(
        ::Ai::DuoWorkflows::SessionArtifact,
        workflow_id: 42
      )
      type_instance = described_class.send(:new, artifact, {})
      expected_gid = ::Gitlab::GlobalId.build(model_name: 'Ai::DuoWorkflows::Workflow', id: 42).to_s

      expect(type_instance.id).to eq(expected_gid)
    end
  end

  describe '#audit_events_count' do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }
    let_it_be(:artifact) { create(:duo_workflow_session_artifact, workflow: workflow) }

    subject(:type_instance) { described_class.send(:new, artifact, {}) }

    context 'when ClickHouse is not enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        allow(::AuditEvents::AiAuditEvent)
          .to receive(:counts_for_workflows)
          .and_return({ workflow.id => 3 })
      end

      it 'queries PostgreSQL' do
        expect(type_instance.audit_events_count.sync).to eq(3)
        expect(::AuditEvents::AiAuditEvent).to have_received(:counts_for_workflows).with([workflow.id],
          min_created_at: anything)
      end
    end

    context 'when ClickHouse is enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        allow(::AuditEvents::AiAuditEvents::ClickHouseFinder)
          .to receive(:counts_for_workflows)
          .and_return({ workflow.id => 5 })
      end

      it 'queries ClickHouse' do
        expect(type_instance.audit_events_count.sync).to eq(5)
        expect(::AuditEvents::AiAuditEvents::ClickHouseFinder)
          .to have_received(:counts_for_workflows)
          .with([workflow.id], min_created_at: anything)
      end
    end
  end

  describe '#web_path (ClickHouse Hash path)' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workflow_id) { 99 }

    def ch_hash(proj_id, wf_id)
      {
        'id' => wf_id,
        'project_id' => proj_id,
        'workflow_definition' => 'software_development',
        'created_at' => Time.current.to_s
      }
    end

    context 'when the project exists' do
      subject(:type_instance) { described_class.send(:new, ch_hash(project.id, workflow_id), {}) }

      it 'resolves to the project sessions path suffixed with the workflow id' do
        expected = "#{::Gitlab::Routing.url_helpers.project_automate_agent_sessions_path(project)}/#{workflow_id}"

        expect(type_instance.web_path.sync).to eq(expected)
      end
    end

    context 'when the project does not exist' do
      subject(:type_instance) { described_class.send(:new, ch_hash(non_existing_record_id, workflow_id), {}) }

      it 'returns nil' do
        expect(type_instance.web_path.sync).to be_nil
      end
    end

    context 'when project_id is nil' do
      subject(:type_instance) { described_class.send(:new, ch_hash(nil, workflow_id), {}) }

      it 'returns nil without going through BatchLoader' do
        expect(type_instance.web_path).to be_nil
      end
    end
  end

  describe '#download_path (ClickHouse Hash path)' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workflow_id) { 77 }

    def ch_hash(proj_id, wf_id)
      {
        'id' => wf_id,
        'project_id' => proj_id,
        'workflow_definition' => 'software_development',
        'created_at' => Time.current.to_s
      }
    end

    context 'when the project exists' do
      subject(:type_instance) { described_class.send(:new, ch_hash(project.id, workflow_id), {}) }

      it 'resolves to the artifact download path for the project and workflow' do
        expected = ::Gitlab::Routing.url_helpers
          .download_project_security_agent_artifact_path(project, workflow_id)

        expect(type_instance.download_path.sync).to eq(expected)
      end
    end

    context 'when the project does not exist' do
      subject(:type_instance) { described_class.send(:new, ch_hash(non_existing_record_id, workflow_id), {}) }

      it 'returns nil' do
        expect(type_instance.download_path.sync).to be_nil
      end
    end

    context 'when project_id is nil' do
      subject(:type_instance) { described_class.send(:new, ch_hash(nil, workflow_id), {}) }

      it 'returns nil without going through BatchLoader' do
        expect(type_instance.download_path).to be_nil
      end
    end
  end

  it 'exposes triggeredBy as nullable UserType' do
    expect(described_class.fields['triggeredBy'].type.to_type_signature).to eq('UserCore')
  end

  describe '#triggered_by (ActiveRecord path)' do
    let_it_be(:user) { create(:user) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, user: user) }
    let_it_be(:artifact) { create(:duo_workflow_session_artifact, workflow: workflow) }

    subject(:type_instance) { described_class.send(:new, artifact, {}) }

    it 'returns the user associated with the artifact' do
      expect(type_instance.triggered_by).to eq(user)
    end
  end

  describe '#triggered_by (ClickHouse Hash path)' do
    let_it_be(:user) { create(:user) }

    def ch_hash(user_id)
      {
        'id' => 99,
        'user_id' => user_id,
        'project_id' => nil,
        'workflow_definition' => 'software_development',
        'created_at' => Time.current.to_s
      }
    end

    context 'when the user exists' do
      subject(:type_instance) { described_class.send(:new, ch_hash(user.id), {}) }

      it 'batch-loads and returns the user' do
        expect(type_instance.triggered_by.sync).to eq(user)
      end
    end

    context 'when the user does not exist' do
      subject(:type_instance) { described_class.send(:new, ch_hash(non_existing_record_id), {}) }

      it 'returns nil' do
        expect(type_instance.triggered_by.sync).to be_nil
      end
    end
  end
end
