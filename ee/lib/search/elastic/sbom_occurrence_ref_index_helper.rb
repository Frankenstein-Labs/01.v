# frozen_string_literal: true

module Search
  module Elastic
    module SbomOccurrenceRefIndexHelper
      class << self
        def indexing_allowed?
          ::Gitlab::CurrentSettings.elasticsearch_indexing? &&
            ::Elastic::DataMigrationService.migration_has_finished?(:create_sbom_occurrence_refs_index)
        end

        # Used by the policy, which the ability flag uses to show or hide features on the UI.
        # Reads also need `elasticsearch_search?`: an instance can keep the index up to date
        # while search is switched off, and serving the dependency list from it would fail.
        def advanced_dependency_management_allowed?
          indexing_allowed? && ::Gitlab::CurrentSettings.elasticsearch_search?
        end
      end
    end
  end
end
