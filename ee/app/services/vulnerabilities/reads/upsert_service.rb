# ee/app/services/vulnerabilities/reads/upsert_service.rb
# frozen_string_literal: true

module Vulnerabilities
  module Reads
    # This class will update vulnerabilty reads for a set of corresponding vulnerability records
    # according to the passed attributes set.
    #
    # If any of the passed vulnerabilities does not have a corresponding read, it will ensure it
    # exists in the created state.
    #
    # If no attributes are passed, it will only ensure that the vulnerabilities have corresponding
    # vulnerability reads created.

    class UpsertService
      include BaseServiceUtility

      BATCH_SIZE = 1000

      def initialize(vulnerabilities, attributes = {}, projects: [], update_all_vulnerabilities: false)
        @attributes = attributes
        @vulnerabilities = ensure_vulnerability_relation(vulnerabilities)
        # Project is only needed for feature flag purposes
        @projects = Array(projects)
        # temporary needed when turn_off_vulnerability_read_create_db_trigger_function is disabled
        # we still want to use the service to update fields not updated by the trigger
        @update_all_vulnerabilities = update_all_vulnerabilities
      end

      def execute
        return if @vulnerabilities.empty?

        # Until we globally enable the FF, we have to filter off vulns for projects where the FF is is not on so
        # so that we can make sure to run the service for projects where the trigger is switched off, else we'll
        # cause data inconsistencies.
        unless @update_all_vulnerabilities
          @projects = @projects.select do |p|
            Feature.enabled?(:turn_off_vulnerability_read_create_db_trigger_function, p)
          end
        end

        @vulnerabilities = @vulnerabilities.with_project(@projects)

        @vulnerabilities.each_batch(of: BATCH_SIZE) do |vulnerability_batch|
          SecApplicationRecord.feature_flagged_transaction_for(@projects) do
            vulns_missing_reads = vulnerability_batch.left_joins(:vulnerability_read)
                                                     .merge(Vulnerabilities::Read.by_vulnerabilities(nil))
                                                     .pluck_primary_key
            new_read_vulnerability_ids = create_missing_reads(vulns_missing_reads)

            next unless attributes.any?

            vulnerability_read_batch = Vulnerabilities::Read.by_vulnerabilities(vulnerability_batch)
                                                            .excluding_vulnerabilities(new_read_vulnerability_ids)

            vulnerability_read_batch.update_all(attributes)

            SecApplicationRecord.current_transaction.after_commit do
              log_batch("Updated vulnerability_reads", vulnerability_read_batch)
              Vulnerabilities::BulkEsOperationService.new(vulnerability_batch).execute
            end
          end
        end

        success
      end

      private

      attr_reader :attributes, :batch_size

      # We do this to avoid nesting a subquery of the vulnerabilities in itself if passed a relation.
      def ensure_vulnerability_relation(vulnerabilities_parameter)
        if vulnerabilities_parameter.is_a?(ActiveRecord::Relation)
          vulnerabilities_parameter.dup
        else
          Vulnerability.by_ids(vulnerabilities_parameter)
        end
      end

      def create_missing_reads(missing_read_vuln_ids)
        return [] if missing_read_vuln_ids.empty?

        # rubocop:disable CodeReuse/ActiveRecord -- This is a very specific set of eager and pre loads needed for
        # building a full vulnerability record in as few queries as possible, but needing to cross DB boundaries.
        missing_vulnerability_batch = Vulnerability.by_ids(missing_read_vuln_ids)
                                                   .eager_load(
                                                     :issue_links,
                                                     :merge_request_links,
                                                     findings: [
                                                       :remediations,
                                                       :scanner,
                                                       :identifiers,
                                                       { finding_identifiers: :identifier }
                                                     ]
                                                   )
                                                   .preload(
                                                     :notes,
                                                     :merge_requests,
                                                     :related_issues,
                                                     project: [
                                                       :route,
                                                       { project_namespace: :route },
                                                       { namespace: :route }
                                                     ]
                                                   )
        # rubocop:enable CodeReuse/ActiveRecord

        batch = build_vulnerability_reads_batch(missing_vulnerability_batch)
        new_read_ids = perform_bulk_insert(batch)
        ::SecApplicationRecord.current_transaction.after_commit do
          Vulnerabilities::BulkEsOperationService.new(missing_vulnerability_batch).execute
        end
        log_batch("New vulnerability_reads created", batch)
        new_read_ids
      end

      def build_vulnerability_reads_batch(vulnerability_batch)
        vulnerability_batch.filter_map do |vulnerability|
          next unless vulnerability.present_on_default_branch?
          next unless vulnerability.finding

          build_vulnerability_read(vulnerability)
        end
      end

      def perform_bulk_insert(vulnerability_reads_for_insert)
        # rubocop:disable Search/VulnerabilityBulkOperationElasticsearchSync -- ES sync handled by
        # the after_commit block in create_missing_reads
        ::Vulnerabilities::Read.bulk_upsert!(
          vulnerability_reads_for_insert,
          unique_by: %i[uuid],
          returns: [:vulnerability_id]
        ) do |item_attrs|
          item_attrs.delete('id') # `id` is an auto-generated sequence
        end
        # rubocop:enable Search/VulnerabilityBulkOperationElasticsearchSync
      end

      def build_vulnerability_read(vulnerability)
        ::Vulnerabilities::Read.new(
          {
            vulnerability_id: vulnerability.id,
            project_id: vulnerability.project_id,
            uuid: vulnerability.finding.uuid,
            scanner_id: vulnerability.finding.scanner_id,
            severity: vulnerability.severity,
            state: vulnerability.state,
            report_type: vulnerability.report_type,
            resolved_on_default_branch: vulnerability.resolved_on_default_branch,
            # This map won't cause an N+1 thanks to the identifier eager_load earlier in the service
            identifier_names: vulnerability.finding.identifiers.map(&:name),
            location_image: vulnerability.finding.location['image'],
            has_remediations: vulnerability.has_remediations?,
            cluster_agent_id: vulnerability.location.dig('kubernetes_resource', 'agent_id'),
            traversal_ids: vulnerability.project.namespace.traversal_ids,
            archived: vulnerability.project.archived?,
            auto_resolved: vulnerability.auto_resolved?,
            security_project_tracked_context_id: vulnerability.finding.security_project_tracked_context_id
          }.merge!(@attributes)
        )
      end

      def log_batch(message, records)
        return if records.blank?

        records.group_by(&:project_id).each do |project_id, project_records|
          ::Gitlab::AppLogger.info(
            class: self.class.name,
            message: message,
            project_id: project_id,
            count: project_records.count
          )
        end
      end
    end
  end
end
