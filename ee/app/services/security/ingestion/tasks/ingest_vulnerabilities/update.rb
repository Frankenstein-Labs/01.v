# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestVulnerabilities
        # Updates the existing vulnerability records
        # by using a single database query.
        class Update < AbstractTask
          include Gitlab::Ingestion::BulkUpdatableTask

          self.model = Vulnerability
          self.scope = 'vulnerabilities.present_on_default_branch IS TRUE'

          private

          # Important Note:
          #   Sorting by the primary key (vulnerabilities.id) is important to
          #   prevent deadlock errors. This UPDATE locks the matched rows in the
          #   order they appear in the VALUES list, so concurrent ingestion
          #   transactions (e.g. advisory-driven CVS scans and pipeline report
          #   ingestion) that touch the same vulnerabilities must acquire those
          #   row locks in a consistent order. See gitlab-org/gitlab#603318.
          def attributes
            finding_maps
              .sort_by(&:vulnerability_id)
              .map do |finding_map|
                attributes_for(
                  finding_map.vulnerability_id,
                  finding_map.report_finding,
                  finding_map.finding_id
                )
              end
          end

          def attributes_for(vulnerability_id, report_finding, finding_id)
            {
              id: vulnerability_id,
              title: report_finding.name.truncate(::Issuable::TITLE_LENGTH_MAX),
              solution: report_finding.solution,
              severity: report_finding.severity,
              resolved_on_default_branch: false,
              updated_at: Time.zone.now,
              cvss: report_finding.cvss,
              finding_id: finding_id
            }
          end
        end
      end
    end
  end
end
