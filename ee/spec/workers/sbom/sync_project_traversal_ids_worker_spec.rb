# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncProjectTraversalIdsWorker, feature_category: :dependency_management, type: :worker do
  let_it_be(:project) { create(:project) }
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence, traversal_ids: [], project: project) }

  let(:job_args) { project.id }

  subject(:perform) { described_class.new.perform(job_args) }

  it_behaves_like 'an idempotent worker'

  it 'changes the `traversal_ids` of the record' do
    expect { perform }.to change { sbom_occurrence.reload.traversal_ids }.from([]).to(project.namespace.traversal_ids)
  end
end
