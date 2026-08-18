# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::TrackOccurrenceRefsEsService, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let_it_be(:changed_occurrence) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
  let_it_be(:created_occurrence) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
  let_it_be(:unchanged_occurrence) { create(:sbom_occurrence, project: project, pipeline: pipeline) }

  let_it_be(:changed_occurrence_ref) do
    create(:sbom_occurrence_ref, occurrence: changed_occurrence, project: project, pipeline: pipeline)
  end

  let_it_be(:created_occurrence_ref) do
    create(:sbom_occurrence_ref, occurrence: created_occurrence, project: project, pipeline: pipeline)
  end

  let_it_be(:unchanged_occurrence_ref) do
    create(:sbom_occurrence_ref, occurrence: unchanged_occurrence, project: project, pipeline: pipeline)
  end

  let(:changed_map) do
    build(:sbom_occurrence_map).tap do |map|
      map.occurrence_id = changed_occurrence.id
      map.occurrence_changed = true
    end
  end

  let(:created_map) do
    build(:sbom_occurrence_map).tap do |map|
      map.occurrence_id = created_occurrence.id
      map.ref_created = true
    end
  end

  let(:unchanged_map) do
    build(:sbom_occurrence_map).tap do |map|
      map.occurrence_id = unchanged_occurrence.id
    end
  end

  let(:occurrence_maps) { [changed_map, created_map, unchanged_map] }

  subject(:execute) { described_class.execute(project, occurrence_maps) }

  describe '#execute' do
    it 'tracks the refs of the changed and newly-created occurrences via BulkEsOperationService' do
      bulk_service = instance_double(::Sbom::BulkEsOperationService, execute: true)

      expect(::Sbom::BulkEsOperationService).to receive(:new) do |relation|
        expect(relation).to match_array([changed_occurrence_ref, created_occurrence_ref])

        bulk_service
      end

      execute

      expect(bulk_service).to have_received(:execute)
    end

    context 'when sbom_occurrence_ref_es_indexing is disabled' do
      before do
        stub_feature_flags(sbom_occurrence_ref_es_indexing: false)
      end

      it 'does not track any occurrence refs' do
        expect(::Sbom::BulkEsOperationService).not_to receive(:new)

        execute
      end
    end

    context 'when no occurrence has changed or had a ref created' do
      let(:occurrence_maps) { [unchanged_map] }

      it 'does not track any occurrence refs' do
        expect(::Sbom::BulkEsOperationService).not_to receive(:new)

        execute
      end
    end

    context 'when occurrence_maps is empty' do
      let(:occurrence_maps) { [] }

      it 'does not track any occurrence refs' do
        expect(::Sbom::BulkEsOperationService).not_to receive(:new)

        execute
      end
    end
  end
end
