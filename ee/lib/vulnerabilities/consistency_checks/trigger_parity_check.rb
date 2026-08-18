# frozen_string_literal: true

module Vulnerabilities
  module ConsistencyChecks
    class TriggerParityCheck < BaseCheck
      BATCH_SIZE = 1000

      def fix!
        fix_vulnerability_occurrence_id_mismatches
        fix_scanner_id_mismatches
        fix_uuid_mismatches
        fix_has_issues_mismatches
        fix_has_merge_request_mismatches
        create_missing_vulnerability_reads
      rescue StandardError => e
        log('Failed to fix vulnerability_reads', error: e.message, backtrace: e.backtrace)
        raise
      end

      private

      def fix_scanner_id_mismatches
        total = 0

        mismatched_scanner_ids_relation.each_batch(of: BATCH_SIZE) do |batch|
          count = Vulnerabilities::Read.connection.exec_update(<<~SQL)
            UPDATE vulnerability_reads
            SET scanner_id = vo.scanner_id
            FROM vulnerability_occurrences vo
            WHERE vulnerability_reads.vulnerability_occurrence_id IN (#{batch.select(:vulnerability_occurrence_id).to_sql})
              AND vo.id = vulnerability_reads.vulnerability_occurrence_id
              AND vulnerability_reads.scanner_id != vo.scanner_id
          SQL

          total += count
        end

        log('Fixed scanner_id mismatches', count: total) if total > 0
      end

      def fix_uuid_mismatches
        total = 0

        mismatched_uuid_relation.each_batch(of: BATCH_SIZE) do |batch|
          count = Vulnerabilities::Read.connection.exec_update(<<~SQL)
            UPDATE vulnerability_reads
            SET uuid = vo.uuid
            FROM vulnerability_occurrences vo
            WHERE vulnerability_reads.vulnerability_occurrence_id IN (#{batch.select(:vulnerability_occurrence_id).to_sql})
              AND vo.id = vulnerability_reads.vulnerability_occurrence_id
              AND vulnerability_reads.uuid != vo.uuid
          SQL

          total += count
        end

        log('Fixed uuid mismatches', count: total) if total > 0
      end

      def fix_vulnerability_occurrence_id_mismatches
        total = 0

        mismatched_occurrence_id_relation.each_batch(of: BATCH_SIZE) do |batch|
          count = Vulnerabilities::Read.connection.exec_update(<<~SQL)
            UPDATE vulnerability_reads
            SET vulnerability_occurrence_id = v.finding_id
            FROM vulnerabilities v
            WHERE vulnerability_reads.vulnerability_id IN (#{batch.select(:vulnerability_id).to_sql})
              AND vulnerability_reads.vulnerability_id = v.id
              AND (vulnerability_reads.vulnerability_occurrence_id IS NULL
                   OR vulnerability_reads.vulnerability_occurrence_id != v.finding_id)
          SQL

          total += count
        end

        log('Fixed vulnerability_occurrence_id mismatches', count: total) if total > 0
      end

      def fix_has_issues_mismatches
        total = 0

        mismatched_has_issues_relation.each_batch(of: BATCH_SIZE) do |batch|
          count = Vulnerabilities::Read.connection.exec_update(<<~SQL)
            UPDATE vulnerability_reads
            SET has_issues = (
              EXISTS (
                SELECT 1 FROM vulnerability_issue_links vil
                WHERE vil.vulnerability_occurrence_id = vulnerability_reads.vulnerability_occurrence_id
              )
            )
            WHERE vulnerability_reads.vulnerability_id IN (#{batch.select(:vulnerability_id).to_sql})
          SQL

          total += count
        end

        log('Fixed has_issues mismatches', count: total) if total > 0
      end

      def fix_has_merge_request_mismatches
        total = 0

        mismatched_has_merge_request_relation.each_batch(of: BATCH_SIZE) do |batch|
          count = Vulnerabilities::Read.connection.exec_update(<<~SQL)
            UPDATE vulnerability_reads
            SET has_merge_request = (
              EXISTS (
                SELECT 1 FROM vulnerability_merge_request_links vmrl
                WHERE vmrl.vulnerability_occurrence_id = vulnerability_reads.vulnerability_occurrence_id
              )
            )
            WHERE vulnerability_reads.vulnerability_id IN (#{batch.select(:vulnerability_id).to_sql})
          SQL

          total += count
        end

        log('Fixed has_merge_request mismatches', count: total) if total > 0
      end

      def create_missing_vulnerability_reads
        total = 0

        # Use :findings (the has_many association), not :finding (which is a memoized method, not an association)
        missing_reads_relation.includes(:findings, :issue_links, :merge_request_links).in_batches(of: BATCH_SIZE) do |batch| # rubocop:disable CodeReuse/ActiveRecord, Cop/InBatches -- each_batch does not support includes
          records = batch.to_a.filter_map do |vulnerability|
            finding = vulnerability.finding
            next unless finding

            {
              vulnerability_id: vulnerability.id,
              project_id: vulnerability.project_id,
              scanner_id: finding.scanner_id,
              report_type: vulnerability.report_type,
              severity: vulnerability.severity,
              state: vulnerability.state,
              resolved_on_default_branch: vulnerability.resolved_on_default_branch,
              uuid: finding.uuid,
              vulnerability_occurrence_id: finding.id,
              has_issues: vulnerability.issue_links.any?,
              has_merge_request: vulnerability.merge_request_links.any?,
              location_image: extract_location_image(finding),
              cluster_agent_id: extract_cluster_agent_id(finding),
              casted_cluster_agent_id: extract_casted_cluster_agent_id(finding)
            }
          end

          next if records.empty?

          result = Vulnerabilities::Read.upsert_all(
            records,
            unique_by: :index_vulnerability_reads_on_vulnerability_id,
            on_duplicate: :skip
          )

          total += result.length
        end

        log('Created missing vulnerability_reads', count: total) if total > 0
      end

      def mismatched_scanner_ids_relation
        Vulnerabilities::Read
          .by_projects(project)
          .where.not(vulnerability_occurrence_id: nil) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .joins('INNER JOIN vulnerability_occurrences vo ON vo.id = vulnerability_reads.vulnerability_occurrence_id') # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .where('vulnerability_reads.scanner_id != vo.scanner_id') # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
      end

      def mismatched_uuid_relation
        Vulnerabilities::Read
          .by_projects(project)
          .where.not(vulnerability_occurrence_id: nil) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .joins('INNER JOIN vulnerability_occurrences vo ON vo.id = vulnerability_reads.vulnerability_occurrence_id') # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .where('vulnerability_reads.uuid != vo.uuid') # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
      end

      def mismatched_occurrence_id_relation
        Vulnerabilities::Read
          .by_projects(project)
          .joins(:vulnerability) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .where(<<~SQL.squish) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
            vulnerability_reads.vulnerability_occurrence_id IS NULL
            OR vulnerability_reads.vulnerability_occurrence_id != vulnerabilities.finding_id
          SQL
      end

      def mismatched_has_issues_relation
        Vulnerabilities::Read
          .by_projects(project)
          .where(<<~SQL.squish) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
            vulnerability_reads.has_issues != (
              EXISTS (
                SELECT 1 FROM vulnerability_issue_links vil
                WHERE vil.vulnerability_occurrence_id = vulnerability_reads.vulnerability_occurrence_id
              )
            )
          SQL
      end

      def mismatched_has_merge_request_relation
        Vulnerabilities::Read
          .by_projects(project)
          .where(<<~SQL.squish) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
            vulnerability_reads.has_merge_request != (
              EXISTS (
                SELECT 1 FROM vulnerability_merge_request_links vmrl
                WHERE vmrl.vulnerability_occurrence_id = vulnerability_reads.vulnerability_occurrence_id
              )
            )
          SQL
      end

      def missing_reads_relation
        ::Vulnerability
          .where(project: project) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .where(present_on_default_branch: true) # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
          .where.not( # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
            Vulnerabilities::Read
              .where('vulnerability_reads.vulnerability_id = vulnerabilities.id') # rubocop:disable CodeReuse/ActiveRecord -- bespoke consistency check
              .arel.exists
          )
      end

      def extract_location_image(finding)
        finding.location['image']
      end

      def extract_cluster_agent_id(finding)
        finding.location.dig('kubernetes_resource', 'agent_id')
      end

      def extract_casted_cluster_agent_id(finding)
        extract_cluster_agent_id(finding)&.to_i
      end
    end
  end
end
