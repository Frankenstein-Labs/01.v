# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::DeleteNotPresentOccurrencesService, feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:source) { create(:sbom_source) }

  let_it_be(:tracked_context) do
    create(:security_project_tracked_context, :tracked,
      project: project, context_name: pipeline.ref, context_type: :branch)
  end

  subject(:execute) { described_class.execute(pipeline, ingested_ids) }

  describe '#execute' do
    shared_examples 'it no-ops with failed sbom jobs' do
      context 'when there are failed sbom jobs' do
        let(:options) { { artifacts: { reports: { cyclonedx: 'foo' } } } }

        before do
          create(:ee_ci_build, :failed, pipeline: pipeline, options: options)
        end

        it 'does not affect occurrence count' do
          expect { execute }.not_to change { Sbom::Occurrence.count }
        end

        it 'does not affect occurrence ref count' do
          expect { execute }.not_to change { Sbom::OccurrenceRef.count }
        end

        it_behaves_like 'does not sync with ES when no vulnerabilities'
      end
    end

    shared_examples 'tracks occurrence ref deletions in ES' do
      before do
        allow(::Search::Elastic::SbomOccurrenceRefIndexHelper).to receive(:indexing_allowed?).and_return(true)
      end

      it 'tracks the deleted refs in Elasticsearch' do
        ref_ids = expected_deleted_ref_ids # capture before the refs are deleted

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*refs|
          expect(refs).to all(be_a(::Search::Elastic::References::Sbom::OccurrenceRef))
          expect(refs.map(&:identifier)).to match_array(ref_ids)
        end

        execute
      end

      context 'when indexing is not allowed' do
        before do
          allow(::Search::Elastic::SbomOccurrenceRefIndexHelper).to receive(:indexing_allowed?).and_return(false)
        end

        it 'does not track the deleted refs in Elasticsearch' do
          expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

          execute
        end
      end

      context 'when sbom_occurrence_ref_es_indexing is disabled' do
        before do
          stub_feature_flags(sbom_occurrence_ref_es_indexing: false)
        end

        it 'does not track the deleted refs in Elasticsearch' do
          expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

          execute
        end
      end
    end

    context 'when project has occurrences' do
      let_it_be_with_reload(:occurrences) do
        create_list(:sbom_occurrence, 4, :with_refs, pipeline: pipeline, source: source,
          tracked_contexts: [tracked_context])
      end

      context 'when all occurrences have been removed' do
        let(:ingested_ids) { [] }
        let(:expected_deleted_ref_ids) do
          Sbom::OccurrenceRef.by_tracked_context(tracked_context.id).pluck(:id)
        end

        it 'deletes the refs for the tracked context' do
          expect { execute }.to change {
            Sbom::OccurrenceRef.by_tracked_context(tracked_context.id).count
          }.from(4).to(0)
        end

        it_behaves_like 'tracks occurrence ref deletions in ES'

        context 'when occurrences have associated vulnerabilities' do
          let(:vulnerabilities) { create_list(:vulnerability, 2, :with_read, project: project) }
          let(:expected_vulnerability_ids) { vulnerabilities.map(&:id) }

          before do
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[0], vulnerability: vulnerabilities[0])
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[1], vulnerability: vulnerabilities[1])
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[2], vulnerability: vulnerabilities[0])
          end

          it 'deletes matching occurrences' do
            expect { execute }.to change { project.sbom_occurrences.reload.count }.from(4).to(0)
          end

          it_behaves_like 'it syncs vulnerabilities with ES',
            -> { vulnerabilities.map { |v| v.vulnerability_read.id } }
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end

      context 'when a subset of occurrences have been removed' do
        let(:ingested_ids) { occurrences.sample(2).map(&:id) }
        let(:ingested_occurrences) { occurrences.select { |occ| ingested_ids.include?(occ.id) } }
        let(:expected_deleted_ref_ids) do
          deleted_ids = occurrences.map(&:id) - ingested_ids
          Sbom::OccurrenceRef.by_tracked_context(tracked_context.id).by_occurrence(deleted_ids).pluck(:id)
        end

        it_behaves_like 'tracks occurrence ref deletions in ES'

        context 'when deleted occurrences have associated vulnerabilities' do
          let(:vulnerabilities) { create_list(:vulnerability, 4, :with_read, project: project) }
          let(:deleted_occurrences) { occurrences.reject { |occ| ingested_ids.include?(occ.id) } }
          let!(:deleted_occurrence_vulnerabilities) do
            [
              create(:sbom_occurrences_vulnerability, occurrence: deleted_occurrences[0],
                vulnerability: vulnerabilities[0]),
              create(:sbom_occurrences_vulnerability, occurrence: deleted_occurrences[1],
                vulnerability: vulnerabilities[1])
            ]
          end

          let(:expected_vulnerability_ids) { deleted_occurrence_vulnerabilities.map(&:vulnerability_id) }

          before do
            create(:sbom_occurrences_vulnerability, occurrence: ingested_occurrences[0],
              vulnerability: vulnerabilities[2])
            create(:sbom_occurrences_vulnerability, occurrence: ingested_occurrences[1],
              vulnerability: vulnerabilities[3])
          end

          it 'deletes the non-ingested occurrences' do
            execute

            expect(project.sbom_occurrences.reload.map(&:id)).to match_array(ingested_ids)
          end

          it_behaves_like 'it syncs vulnerabilities with ES',
            -> {
              deleted_occurrence_vulnerabilities.map do |ov|
                Vulnerability.find(ov.vulnerability_id).vulnerability_read.id
              end
            }
        end

        context 'when deleted occurrences have no associated vulnerabilities' do
          it 'deletes the non-ingested occurrences' do
            execute

            expect(project.sbom_occurrences.reload.map(&:id)).to match_array(ingested_ids)
          end

          it_behaves_like 'does not sync with ES when no vulnerabilities'
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end
    end

    context 'when an occurrence is referenced by another tracked context' do
      let_it_be(:other_context) { create(:security_project_tracked_context, :tracked, project: project) }
      let_it_be_with_reload(:occurrence) do
        create(:sbom_occurrence, :with_refs, pipeline: pipeline, source: source,
          tracked_contexts: [tracked_context, other_context])
      end

      let(:ingested_ids) { [] }
      let(:expected_deleted_ref_ids) do
        Sbom::OccurrenceRef.by_tracked_context(tracked_context.id).by_occurrence(occurrence.id).pluck(:id)
      end

      it_behaves_like 'tracks occurrence ref deletions in ES'

      it 'deletes only the ref for the current tracked context' do
        expect { execute }.to change {
          Sbom::OccurrenceRef.by_tracked_context(tracked_context.id).count
        }.from(1).to(0)
      end

      it 'does not delete the ref for the other tracked context' do
        expect { execute }.not_to change {
          Sbom::OccurrenceRef.by_tracked_context(other_context.id).count
        }
      end

      it 'does not delete the occurrence because it is still referenced elsewhere' do
        expect { execute }.not_to change { project.sbom_occurrences.reload.count }
      end

      it_behaves_like 'does not sync with ES when no vulnerabilities'
    end

    context 'when project has filtered out occurrence' do
      let_it_be_with_reload(:occurrences) do
        create_list(:sbom_occurrence, 4, :registry_occurrence, :with_refs, pipeline: pipeline,
          tracked_contexts: [tracked_context])
      end

      let(:ingested_ids) { occurrences.sample(2).map(&:id) }

      it 'does not delete filtered out occurrence' do
        expect { execute }.not_to change { project.sbom_occurrences.reload.count }
      end

      it 'does not delete the refs of filtered out occurrences' do
        expect { execute }.not_to change { Sbom::OccurrenceRef.count }
      end

      it_behaves_like 'does not sync with ES when no vulnerabilities'

      it_behaves_like 'it no-ops with failed sbom jobs'
    end
  end
end
