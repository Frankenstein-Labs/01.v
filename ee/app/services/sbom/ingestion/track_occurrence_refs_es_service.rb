# frozen_string_literal: true

module Sbom
  module Ingestion
    class TrackOccurrenceRefsEsService
      include Gitlab::Utils::StrongMemoize

      def self.execute(project, occurrence_maps)
        new(project, occurrence_maps).execute
      end

      def initialize(project, occurrence_maps)
        @project = project
        @occurrence_maps = occurrence_maps
      end

      def execute
        return unless Feature.enabled?(:sbom_occurrence_ref_es_indexing, project.root_ancestor)
        return if changed_occurrence_ids.empty?

        # Not scoped to a single tracked_context: an occurrence can have multiple
        # OccurrenceRef rows (one per tracked branch/tag), and a change to the
        # occurrence's denormalized data needs to be reflected in all of them.
        relation = Sbom::OccurrenceRef.by_occurrence(changed_occurrence_ids)

        ::Sbom::BulkEsOperationService.new(relation).execute
      end

      private

      attr_reader :project, :occurrence_maps

      def changed_occurrence_ids
        occurrence_maps.select { |map| map.occurrence_changed || map.ref_created }
          .map(&:occurrence_id).uniq
      end
      strong_memoize_attr :changed_occurrence_ids
    end
  end
end
