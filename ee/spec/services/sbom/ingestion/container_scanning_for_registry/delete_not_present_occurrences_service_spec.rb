# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::ContainerScanningForRegistry::DeleteNotPresentOccurrencesService, feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:source) { create(:sbom_source, source_type: :container_scanning_for_registry) }

  let_it_be(:tracked_context) do
    create(:security_project_tracked_context, :tracked,
      project: project, context_name: pipeline.ref, context_type: :branch)
  end

  subject(:execute) { described_class.execute(pipeline, ingested_ids, source.id) }

  shared_examples 'it no-ops with failed sbom jobs' do
    context 'when there are failed sbom jobs' do
      let(:options) { { artifacts: { reports: { cyclonedx: 'foo' } } } }

      before do
        create(:ee_ci_build, :failed, pipeline: pipeline, options: options)
      end

      it 'does not affect occurrence count' do
        expect { execute }.not_to change { Sbom::Occurrence.count }
      end
    end
  end

  describe '#execute' do
    context 'when project has occurrences' do
      let_it_be_with_reload(:occurrences) do
        create_list(:sbom_occurrence, 4, :with_refs, pipeline: pipeline, source: source,
          tracked_contexts: [tracked_context])
      end

      context 'when all occurrences have been removed' do
        let(:ingested_ids) { [] }

        it 'deletes all occurrences' do
          expect { execute }.to change { project.sbom_occurrences.reload.count }.from(4).to(0)
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end

      context 'when a subset of occurrences have been removed' do
        let(:ingested_occurrences) { occurrences.sample(2) }
        let(:ingested_ids) { ingested_occurrences.map(&:id) }

        it 'deletes the non-ingested occurrences' do
          execute

          expect(project.sbom_occurrences.reload).to match_array(ingested_occurrences)
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end
    end

    context 'when project has occurrences with multiple sources' do
      let_it_be(:another_source) { create(:sbom_source) }
      let_it_be_with_reload(:registry_occurrences) do
        create_list(:sbom_occurrence, 2, :with_refs, pipeline: pipeline, source: source,
          tracked_contexts: [tracked_context])
      end

      let_it_be_with_reload(:other_source_occurrences) do
        create_list(:sbom_occurrence, 2, :with_refs, pipeline: pipeline, source: another_source,
          tracked_contexts: [tracked_context])
      end

      let(:ingested_ids) { [] }

      it 'deletes only the registry source occurrences' do
        execute

        expect(project.sbom_occurrences.reload).to match_array(other_source_occurrences)
      end

      it 'deletes only the refs for the registry source occurrences' do
        expect { execute }.to change { Sbom::OccurrenceRef.count }.by(-registry_occurrences.size)
      end

      it 'does not delete refs of occurrences from another source' do
        execute

        other_source_occurrences.each do |occurrence|
          expect(occurrence.occurrence_refs.reload).not_to be_empty
        end
      end

      it_behaves_like 'it no-ops with failed sbom jobs'
    end
  end
end
