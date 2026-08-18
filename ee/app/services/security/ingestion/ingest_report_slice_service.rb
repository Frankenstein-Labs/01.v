# frozen_string_literal: true

module Security
  module Ingestion
    # Base class to organize the chain of responsibilities
    # for the report slice.
    #
    # Returns the ingested vulnerability IDs.
    class IngestReportSliceService < IngestSliceBaseService
      SEC_DB_TASKS = %i[
        IngestIdentifiers
        IngestFindings
        IngestVulnerabilities
        IncreaseCountersTask
        AttachFindingsToVulnerabilities
        UpdateFindingEnrichmentVulnerabilities
        IngestFindingIdentifiers
        IngestFindingLinks
        IngestFindingSignatures
        IngestFindingEvidence
        IngestVulnerabilityFlags
        IngestVulnerabilityReads
        IngestVulnerabilityStatistics
        IngestVulnerabilityNamespaceStatistics
        IngestRemediations
        IngestFindingRiskScores
        HooksExecution
        MatchAscpComponents
      ].freeze

      # This needs to be defined for the IngestSliceBaseService to work.
      # If operations are added later that interact with gitlab_main tables,
      # they should be added here.
      MAIN_DB_TASKS = %i[].freeze

      def execute
        # This will halt execution of this slice but we will keep calling this service
        # for the rest of the finding maps.
        return [] unless quota.validate!

        Security::Ingestion::Tasks::UpdateVulnerabilityUuids.execute(@pipeline, @finding_maps)

        super
      end

      private

      def quota
        pipeline.project.reset.vulnerability_quota
      end
    end
  end
end
