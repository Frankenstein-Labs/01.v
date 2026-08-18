# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncTraversalIdsService, feature_category: :dependency_management do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :project_id) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project_id)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(project_id) }

    subject(:update_traversal_ids) { service_object.execute }

    context 'when there is no project with given id' do
      let(:project_id) { non_existing_record_id }

      it 'does not raise an error' do
        expect { update_traversal_ids }.not_to raise_error
      end
    end

    context 'when there is a project with given id' do
      let(:project_id) { project.id }

      let_it_be(:project) { create(:project) }
      let_it_be_with_reload(:sbom_occurrence) { create(:sbom_occurrence, project: project) }
      let_it_be(:old_namespace) { create(:namespace) }

      before do
        sbom_occurrence.update_column(:traversal_ids, old_namespace.traversal_ids)
      end

      it 'changes the `traversal_ids` of the sbom_occurrence record' do
        expect { update_traversal_ids }
          .to change {
                sbom_occurrence.reload.traversal_ids
              }.from(old_namespace.traversal_ids).to(project.namespace.traversal_ids)
      end

      describe 'parallel execution' do
        include ExclusiveLeaseHelpers

        let_it_be(:other_project) { create(:project) }

        let(:lease_key) { Sbom::Ingestion.project_lease_key(project_id) }

        before do
          # Speed up retries to avoid long-running tests
          stub_const("#{described_class}::LEASE_TRY_AFTER", 0.01)
          stub_exclusive_lease_taken(lease_key)
        end

        it 'does not permit parallel execution on the same project' do
          expect { update_traversal_ids }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
            .and not_change { sbom_occurrence.reload.traversal_ids }.from(old_namespace.traversal_ids)
        end

        it 'allows parallel execution on different projects' do
          expect { described_class.new(other_project.id).execute }.not_to raise_error
        end
      end

      describe 'batching over records' do
        let!(:other_sbom_occurrence) { create(:sbom_occurrence, project: project) }
        let(:sql_queries) { ActiveRecord::QueryRecorder.new { update_traversal_ids }.log }
        let(:update_queries_count) { sql_queries.count { |query| query.start_with?('UPDATE') } }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
        end

        it 'runs the update query in batches' do
          expect(update_queries_count).to be(2)
        end
      end
    end
  end
end
