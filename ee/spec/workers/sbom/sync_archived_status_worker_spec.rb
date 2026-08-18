# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncArchivedStatusWorker, feature_category: :dependency_management, type: :worker do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence, project: project) }
  let_it_be(:sbom_occurrence_outside_project) { create(:sbom_occurrence) }

  let(:event) do
    ::Projects::ProjectArchivedEvent.new(data: {
      project_id: project.id,
      namespace_id: project.namespace.id,
      root_namespace_id: project.root_namespace.id
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always
  it_behaves_like 'subscribes to event'

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  it 'updates sbom_occurrences archived status' do
    project.update!(archived: true)

    expect { use_event }.to change { sbom_occurrence.reload.archived }.from(false).to(true)
      .and not_change { sbom_occurrence_outside_project.reload.archived }
  end
end
