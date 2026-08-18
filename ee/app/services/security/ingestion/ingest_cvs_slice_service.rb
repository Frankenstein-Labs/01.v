# frozen_string_literal: true

module Security
  module Ingestion
    # Orchestration service for Continuous Vulnerability Scanning (CVS) ingestion.
    #
    # CVS creates vulnerabilities from SBOM (Software Bill of Materials) data by
    # matching components against known advisories. Unlike traditional security
    # scanners that run during CI pipelines, CVS operates asynchronously when
    # advisory databases are updated or SBOM data changes.
    #
    # == Differences from IngestReportSliceService
    #
    # 1. **No pipeline context** - CVS findings are not tied to a specific CI
    #    pipeline run. The `pipeline` parameter is passed as `nil`.
    #
    # 2. **Specialized scanner task** - Uses `IngestCvsSecurityScanners` instead
    #    of the standard scanner ingestion, as CVS uses a dedicated virtual
    #    scanner (`gitlab-sbom-vulnerability-scanner`).
    #
    # 3. **MAIN_DB_TASKS** - Includes `MarkCvsProjectsAsVulnerable` to update
    #    project vulnerability status in gitlab_main.
    #
    # == Task List
    #
    # SEC_DB_TASKS (executed in gitlab_sec transaction):
    # - IngestCvsSecurityScanners - Creates/retrieves the CVS scanner record
    # - IngestIdentifiers - Creates vulnerability identifier records (CVE, CWE, etc.)
    # - IngestFindings - Creates vulnerability finding records
    # - IngestVulnerabilities - Creates/updates vulnerability records
    # - IncreaseCountersTask - Updates vulnerability counters
    # - AttachFindingsToVulnerabilities - Links findings to vulnerabilities
    # - IngestFindingIdentifiers - Creates finding-identifier associations
    # - IngestFindingLinks - Creates external reference links
    # - IngestFindingSignatures - Creates finding signature records
    # - IngestFindingEvidence - Stores evidence data
    # - IngestVulnerabilityFlags - Sets vulnerability flags
    # - IngestVulnerabilityReads - Updates read-optimized vulnerability records
    # - IngestVulnerabilityStatistics - Updates project-level statistics
    # - IngestVulnerabilityNamespaceStatistics - Updates namespace-level statistics
    # - IngestFindingRiskScores - Calculates and stores risk scores
    # - HooksExecution - Triggers webhooks for new vulnerabilities
    #
    # MAIN_DB_TASKS (executed in gitlab_main transaction):
    # - MarkCvsProjectsAsVulnerable - Updates project.has_vulnerabilities flag
    #
    # @see IngestSliceBaseService for the base orchestration logic
    # @see Sbom::CreateVulnerabilitiesService for the CVS entry point
    # @see IngestReportSliceService for standard scanner ingestion
    class IngestCvsSliceService < IngestSliceBaseService
      SEC_DB_TASKS = %i[
        IngestCvsSecurityScanners
        IngestIdentifiers
        IngestFindings
        IngestVulnerabilities
        IncreaseCountersTask
        AttachFindingsToVulnerabilities
        IngestFindingIdentifiers
        IngestFindingLinks
        IngestFindingSignatures
        IngestFindingEvidence
        IngestVulnerabilityFlags
        IngestVulnerabilityReads
        IngestVulnerabilityStatistics
        IngestVulnerabilityNamespaceStatistics
        IngestFindingRiskScores
        HooksExecution
      ].freeze

      MAIN_DB_TASKS = %i[
        MarkCvsProjectsAsVulnerable
      ].freeze

      def self.execute(finding_maps)
        super(nil, finding_maps)
      end
    end
  end
end
