# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportSliceService, feature_category: :dependency_management do
  let_it_be(:num_occurrences) { 10 }
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:occurrence_maps, freeze: false) do
    create_list(:sbom_occurrence_map, num_occurrences, :for_occurrence_ingestion)
  end

  let(:occurrence_sequencer) { ::Ingestion::Sequencer.new }
  let(:source_sequencer) { ::Ingestion::Sequencer.new(start: num_occurrences + 1) }

  subject(:execute) { described_class.execute(pipeline, occurrence_maps) }

  describe '#execute' do
    before do
      allow(::Sbom::Ingestion::Tasks::IngestOccurrences).to receive(:execute).and_wrap_original do |_, _, maps|
        maps.each { |map| map.occurrence_id = occurrence_sequencer.next }
      end

      allow(::Sbom::Ingestion::Tasks::IngestSources).to receive(:execute).and_wrap_original do |_, _, maps|
        maps.each { |map| map.source_id = source_sequencer.next }
      end
    end

    it 'executes ingestion tasks in order' do
      tasks = [
        ::Sbom::Ingestion::Tasks::IngestComponents,
        ::Sbom::Ingestion::Tasks::IngestComponentVersions,
        ::Sbom::Ingestion::Tasks::IngestSources,
        ::Sbom::Ingestion::Tasks::IngestSourcePackages,
        ::Sbom::Ingestion::Tasks::IngestOccurrences,
        ::Sbom::Ingestion::Tasks::IngestOccurrenceRefs,
        ::Sbom::Ingestion::Tasks::IngestOccurrencesVulnerabilities,
        ::Sbom::Ingestion::Tasks::UpdateSecurityPolicyDismissals
      ]

      expect(tasks).to all(receive(:execute).with(pipeline, occurrence_maps).ordered)
      expect(::Sbom::Ingestion::TrackOccurrenceRefsEsService).to receive(:execute)
        .with(pipeline.project, occurrence_maps).ordered

      result = execute
      all_occurrence_ids = result[:occurrence_ids]
      all_source_ids = result[:source_ids]

      expect(all_occurrence_ids).to match_array(occurrence_sequencer.range)
      expect(all_source_ids).to match_array(source_sequencer.range)
    end
  end
end
