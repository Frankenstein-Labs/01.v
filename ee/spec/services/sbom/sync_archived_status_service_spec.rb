# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncArchivedStatusService, feature_category: :dependency_management do
  let_it_be(:project) { create(:project, :archived) }
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence, archived: false, project: project) }
  let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, archived: false, project: project) }

  let(:project_id) { project.id }

  subject(:sync) { described_class.new(project_id).execute }

  it 'updates sbom_occurrences.archived' do
    expect { sync }.to change { sbom_occurrence.reload.archived }.from(false).to(true)
      .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
  end

  context 'when project parent group is archived' do
    let_it_be(:archived_group) { create(:group, :archived) }
    let_it_be(:project) { create(:project, group: archived_group, archived: false) }
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, archived: false, project: project) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, archived: false, project: project) }

    it 'marks occurrences as archived due to ancestor' do
      expect { sync }.to change { sbom_occurrence.reload.archived }.from(false).to(true)
        .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
    end
  end

  context 'when project has multiple batches of sbom_occurrences' do
    before do
      stub_const("#{described_class}::BATCH_SIZE", 1)
    end

    it 'updates all sbom_occurrences in batches' do
      expect { sync }.to change { sbom_occurrence.reload.archived }.from(false).to(true)
        .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
    end
  end

  context 'when project does not exist with id' do
    let(:project_id) { non_existing_record_id }

    it 'does not raise' do
      expect { sync }.not_to raise_error
    end
  end

  context 'when lease is taken' do
    include ExclusiveLeaseHelpers

    let_it_be(:other_project) { create(:project) }

    let(:lease_key) { Sbom::Ingestion.project_lease_key(project_id) }

    before do
      # Speed up retries to avoid long-running tests
      stub_const("#{described_class}::LEASE_TRY_AFTER", 0.01)
      stub_exclusive_lease_taken(lease_key)
    end

    it 'does not permit parallel execution on the same project' do
      expect { sync }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
                          .and not_change { sbom_occurrence.reload.archived }
    end

    it 'allows parallel execution on different projects' do
      expect { described_class.new(other_project.id).execute }.not_to raise_error
    end
  end
end
