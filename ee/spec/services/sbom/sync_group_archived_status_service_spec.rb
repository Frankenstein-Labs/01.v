# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncGroupArchivedStatusService, feature_category: :dependency_management do
  let_it_be(:group) { create(:group, :archived) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1, archived: false) }
  let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_2, archived: false) }

  let(:group_id) { group.id }

  subject(:sync) { described_class.new(group_id).execute }

  describe '#execute' do
    it 'updates archived status for projects with occurrences' do
      expect { sync }.to change { sbom_occurrence_1.reload.archived }.from(false).to(true)
        .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it 'does nothing' do
        expect { sync }.not_to change { sbom_occurrence_1.reload.archived }
      end
    end

    context 'when group has subgroups' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project_3) { create(:project, group: subgroup) }
      let_it_be(:sbom_occurrence_3) { create(:sbom_occurrence, project: project_3, archived: false) }

      it 'updates archived status for projects in subgroups too' do
        expect { sync }.to change { sbom_occurrence_1.reload.archived }.from(false).to(true)
          .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
          .and change { sbom_occurrence_3.reload.archived }.from(false).to(true)
      end
    end

    context 'when project has no occurrences' do
      let_it_be(:project_without_occurrences) { create(:project, group: group) }

      it 'only updates projects with occurrences' do
        expect { sync }.to change { sbom_occurrence_1.reload.archived }.from(false).to(true)
          .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
      end
    end

    context 'when group has archived parent' do
      let_it_be(:parent_group) { create(:group, :archived) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:child_project_1) { create(:project, group: child_group) }
      let_it_be(:child_project_2) { create(:project, group: child_group) }
      let_it_be(:child_sbom_occurrence_1) { create(:sbom_occurrence, project: child_project_1, archived: false) }
      let_it_be(:child_sbom_occurrence_2) { create(:sbom_occurrence, project: child_project_2, archived: false) }

      let(:group_id) { child_group.id }

      it 'marks occurrences as archived due to ancestor' do
        expect { sync }.to change { child_sbom_occurrence_1.reload.archived }.from(false).to(true)
          .and change { child_sbom_occurrence_2.reload.archived }.from(false).to(true)
      end
    end

    context 'when processing multiple batches' do
      before do
        stub_const("#{described_class}::OCCURRENCE_BATCH_SIZE", 1)
      end

      it 'processes all occurrences across batches' do
        expect { sync }.to change { sbom_occurrence_1.reload.archived }.from(false).to(true)
          .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
      end
    end

    it 'does not have N+1 queries' do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        described_class.new(group_id).execute
      end

      create(:project, group: group).tap do |project|
        create(:sbom_occurrence, project: project)
      end

      expect do
        described_class.new(group_id).execute
      end.not_to exceed_all_query_limit(control)
    end
  end
end
