# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateProjectAncestorsStatusesService, feature_category: :security_asset_inventories do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :project) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project)
    end
  end

  describe '#execute' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:original_parent_group) { create(:group, parent: root_group) }
    let_it_be(:new_parent_group) { create(:group, parent: root_group) }
    let_it_be_with_reload(:project) { create(:project, namespace: original_parent_group) }
    let_it_be_with_reload(:root_sast_analyzer_status) do
      create(:analyzer_namespace_status, namespace: root_group, analyzer_type: 'sast', success: 2, failure: 1)
    end

    let_it_be_with_reload(:original_parent_sast_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: original_parent_group,
        analyzer_type: 'sast',
        success: 2,
        failure: 1
      )
    end

    let_it_be_with_reload(:root_ds_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: root_group,
        analyzer_type: 'dependency_scanning',
        success: 0,
        failure: 1
      )
    end

    let_it_be_with_reload(:original_parent_ds_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: original_parent_group,
        analyzer_type: 'dependency_scanning',
        success: 0,
        failure: 1
      )
    end

    let_it_be_with_reload(:root_sast_iac_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: root_group,
        analyzer_type: 'sast_iac',
        stale: 1
      )
    end

    let_it_be_with_reload(:original_parent_sast_iac_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: original_parent_group,
        analyzer_type: 'sast_iac',
        stale: 1
      )
    end

    let(:service_object) { described_class.new(project) }

    subject(:update_ancestors) { service_object.execute }

    context 'when there are no analyzer statuses' do
      before do
        project.update!(namespace: new_parent_group)
      end

      it 'doesnt decrease statuses from original ancestors or increase for new ancestors' do
        expect { update_ancestors }
          .to not_change { Security::AnalyzerNamespaceStatus.count }
          .and not_change { original_parent_sast_analyzer_status.reload }
          .and not_change { original_parent_ds_analyzer_status.reload }
          .and not_change { root_sast_analyzer_status.reload }

        new_parent_analyzer_status = Security::AnalyzerNamespaceStatus.find_by(namespace_id: new_parent_group.id)

        expect(new_parent_analyzer_status).to be_nil
      end
    end

    context 'when there are analyzer statuses' do
      let!(:sast_analyzer_status) do
        create(:analyzer_project_status, project: project, analyzer_type: 'sast', status: :success)
      end

      let!(:dependency_scanning_analyzer_status) do
        create(:analyzer_project_status, project: project, analyzer_type: 'dependency_scanning', status: :failed)
      end

      let!(:not_configured_analyzer_status) do
        create(:analyzer_project_status, project: project, analyzer_type: 'secret_detection', status: :not_configured)
      end

      let!(:stale_analyzer_status) do
        create(:analyzer_project_status, project: project, analyzer_type: 'sast_iac', status: :stale)
      end

      before do
        project.update!(namespace: new_parent_group)
      end

      it 'decreases statuses from original ancestors and increases new ancestors' do
        original_parent_sast = original_parent_sast_analyzer_status
        original_parent_ds = original_parent_ds_analyzer_status
        original_parent_sast_iac = original_parent_sast_iac_analyzer_status

        expect { update_ancestors }
          .to change { Security::AnalyzerNamespaceStatus.count }.by(3) # one for each configured analyzer type
          .and change { original_parent_sast_analyzer_status.reload.success }.from(original_parent_sast.success).to(1)
          .and change { original_parent_ds_analyzer_status.reload.failure }.from(original_parent_ds.failure).to(0)
          .and change { original_parent_sast_iac_analyzer_status.reload.stale }
            .from(original_parent_sast_iac.stale).to(0)
          .and not_change { root_sast_analyzer_status.reload }
          .and not_change { root_sast_iac_analyzer_status.reload }

        new_parent_sast_status = Security::AnalyzerNamespaceStatus.find_by(
          namespace_id: new_parent_group.id, analyzer_type: 'sast'
        )
        new_parent_dependency_scanning_status = Security::AnalyzerNamespaceStatus.find_by(
          namespace_id: new_parent_group.id, analyzer_type: 'dependency_scanning'
        )
        new_parent_sast_iac_status = Security::AnalyzerNamespaceStatus.find_by(
          namespace_id: new_parent_group.id, analyzer_type: 'sast_iac'
        )
        new_parent_secret_detection_status = Security::AnalyzerNamespaceStatus.find_by(
          namespace_id: new_parent_group.id, analyzer_type: 'secret_detection'
        )

        expect(new_parent_sast_status&.success).to eq(1)
        expect(new_parent_sast_status&.failure).to eq(0)
        expect(new_parent_dependency_scanning_status&.success).to eq(0)
        expect(new_parent_dependency_scanning_status&.failure).to eq(1)
        expect(new_parent_sast_iac_status&.stale).to eq(1)
        # not_configured analyzers should be ignored
        expect(new_parent_secret_detection_status).to be_nil
      end
    end
  end
end
