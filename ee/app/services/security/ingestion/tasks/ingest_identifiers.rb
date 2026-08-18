# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      # UPSERTs the identifiers for the given findings and
      # sets the identifier IDs for each `finding_map`.
      class IngestIdentifiers < AbstractTask
        include Gitlab::Ingestion::BulkInsertableTask

        self.model = Vulnerabilities::Identifier
        self.unique_by = %i[project_id fingerprint]
        self.uses = %i[project_id fingerprint id]

        private

        def after_ingest
          fingerprint_map = return_data.each_with_object({}) do |result, map|
            project_id, fingerprint, id = result
            map[project_id] ||= {}
            map[project_id][fingerprint] = id
          end

          finding_maps.each { |finding_map| finding_map.set_identifier_ids_by(fingerprint_map[finding_map.project.id]) }
        end

        # Important Note:
        #   Sorting identifiers is important to prevent having deadlock
        #   errors which can happen if other threads try to import the same
        #   identifiers in different order.
        def attributes
          report_identifiers.sort_by { |identifier_data| [identifier_data[:project_id], identifier_data[:fingerprint]] }
        end

        def report_identifiers
          @report_identifiers ||= finding_maps
            .flat_map(&:identifier_data)
            .uniq { |identifier_data| [identifier_data[:project_id], identifier_data[:fingerprint]] }
        end
      end
    end
  end
end
