# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SessionArtifacts::PostgresqlFinder, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_project) { create(:project, group: other_group) }
  let_it_be(:workflow1) { create(:duo_workflows_workflow, project: project) }
  let_it_be(:workflow2) { create(:duo_workflows_workflow, project: subgroup_project) }
  let_it_be(:workflow_outside) { create(:duo_workflows_workflow, project: other_project) }

  let_it_be(:artifact1) do
    create(:duo_workflow_session_artifact,
      workflow: workflow1,
      workflow_updated_at: 2.hours.ago)
  end

  let_it_be(:artifact2) do
    create(:duo_workflow_session_artifact,
      workflow: workflow2,
      workflow_updated_at: 1.hour.ago)
  end

  let_it_be(:artifact_outside) do
    create(:duo_workflow_session_artifact, workflow: workflow_outside)
  end

  # Namespace-scoped (project_id: nil) session living on a SUBGROUP. The
  # `in_namespace` scope now walks `self_and_descendants`, so this must surface
  # when the finder is called with the ancestor group as the namespace.
  let_it_be(:subgroup_namespace_workflow) do
    create(:duo_workflows_workflow, :agentic_chat, project: nil, namespace: subgroup, user: create(:user))
  end

  let_it_be(:subgroup_namespace_artifact) do
    create(:duo_workflow_session_artifact, :with_namespace,
      workflow: subgroup_namespace_workflow,
      namespace: subgroup,
      workflow_updated_at: 30.minutes.ago)
  end

  subject(:results) { described_class.new(namespace: group, params: {}).execute }

  describe '#execute' do
    it 'returns all artifacts scoped to the namespace and its subgroups' do
      expect(results).to contain_exactly(artifact1, artifact2, subgroup_namespace_artifact)
    end

    it 'returns a namespace-scoped artifact on a subgroup when querying the ancestor group' do
      expect(results).to include(subgroup_namespace_artifact)
    end

    it 'excludes artifacts from outside the namespace' do
      expect(results).not_to include(artifact_outside)
    end

    it 'orders by workflow_updated_at DESC, workflow_id DESC' do
      expect(results.to_a).to eq([subgroup_namespace_artifact, artifact2, artifact1])
    end

    it 'eager loads the project association' do
      expect(results.first.association(:project)).to be_loaded
    end

    it 'returns nothing for a namespace with no artifacts' do
      empty_group = create(:group)

      expect(described_class.new(namespace: empty_group, params: {}).execute).to be_empty
    end

    context 'with namespace-scoped (group-level) artifacts' do
      let_it_be(:group_workflow) { create(:duo_workflows_workflow, project: nil, namespace: group) }
      let_it_be(:group_artifact) do
        create(:duo_workflow_session_artifact, :with_namespace, workflow: group_workflow, namespace: group)
      end

      let_it_be(:subgroup_workflow) { create(:duo_workflows_workflow, project: nil, namespace: subgroup) }
      let_it_be(:subgroup_artifact) do
        create(:duo_workflow_session_artifact, :with_namespace, workflow: subgroup_workflow, namespace: subgroup)
      end

      it 'includes group-level artifacts attached to the namespace itself' do
        expect(results).to include(group_artifact)
      end

      it 'includes group-level artifacts attached to descendant subgroups' do
        expect(results).to include(subgroup_artifact)
      end
    end

    context 'when filtering by a single workflow_id' do
      subject(:results) do
        described_class.new(namespace: group, params: { workflow_id: workflow2.id }).execute
      end

      it 'returns only the artifact for that workflow' do
        expect(results).to contain_exactly(artifact2)
      end
    end

    # The user filters are ClickHouse-only (see `unsupported_pg_args` on the
    # resolvers), so this finder ignores them rather than filtering.
    context 'when given user filters' do
      let_it_be(:other_user) { create(:user) }
      let_it_be(:other_workflow) do
        create(:duo_workflows_workflow, project: project, user: other_user)
      end

      let_it_be(:other_artifact) do
        create(:duo_workflow_session_artifact, workflow: other_workflow, workflow_updated_at: 3.hours.ago)
      end

      subject(:results) do
        described_class.new(
          namespace: group,
          params: { user_id: workflow1.user_id, not: { user_id: workflow1.user_id } }
        ).execute
      end

      it 'ignores them and returns every artifact in the namespace' do
        expect(results).to include(artifact1, other_artifact)
      end
    end
  end
end
