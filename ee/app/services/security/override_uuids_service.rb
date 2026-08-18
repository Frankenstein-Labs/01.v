# frozen_string_literal: true

# Calibrates the UUID values of findings by trying to
# find an existing `Vulnerabilities::Finding` with one of the
# following approaches:
#
# 1) By using finding signatures
# 2) By using the location information
module Security
  class OverrideUuidsService
    BATCH_SIZE = 100

    def self.execute(security_report)
      new(security_report).execute
    end

    def initialize(security_report)
      @security_report = security_report
      @known_uuids = findings.map(&:uuid).to_set
      @context_unaware_uuids = findings.map(&:context_unaware_uuid).to_set
      @signatures_enabled = project.licensed_feature_available?(:vulnerability_finding_signatures)
    end

    def execute
      return unless override_uuids?

      findings.each_slice(BATCH_SIZE) { |batch| OverrideInBatch.execute(project, batch, existing_scanners, known_uuids, context_unaware_uuids, tracked_context) }

      # This sorting will make sure that the existing findings will be processed
      # before the new findings to prevent collision on the following unique index;
      # (project_id, primary_identifier_id, location_fingerprint, scanner_id)
      findings.sort! { |a, b| b.overridden_uuid.to_s <=> a.overridden_uuid.to_s }
    end

    # We need to run the UUID override logic
    # in batches to prevent loading too many records
    # at once into the memory.
    class OverrideInBatch
      def self.execute(...)
        new(...).execute
      end

      def initialize(project, findings, scanners, known_uuids, context_unaware_uuids, tracked_context)
        @project = project
        @findings = findings
        @scanners = scanners
        @known_uuids = known_uuids
        @context_unaware_uuids = context_unaware_uuids
        @tracked_context = tracked_context
      end

      def execute
        findings.each { |finding| override_for(finding) }
      end

      private

      attr_reader :project, :findings, :scanners, :known_uuids, :context_unaware_uuids, :tracked_context

      def override_for(finding)
        existing_findings = existing_findings_by_signature(finding) + existing_findings_by_location(finding)

        return unless existing_findings.present?

        override_context_unaware_uuid_for(finding, existing_findings)
        override_uuid_for(finding, existing_findings)
      end

      def override_context_unaware_uuid_for(finding, existing_findings)
        existing_finding = existing_findings.first

        if context_unaware_uuids.add?(existing_finding.context_unaware_uuid)
          finding.context_unaware_uuid = existing_finding.context_unaware_uuid
        end
      end

      def override_uuid_for(finding, existing_findings)
        same_context_finding = same_context_finding_from(existing_findings)

        if same_context_finding && known_uuids.add?(same_context_finding.uuid)
          finding.overridden_uuid = finding.uuid
          finding.uuid = same_context_finding.uuid
        end
      end

      def same_context_finding_from(existing_findings)
        existing_findings.find do |existing_finding|
          existing_finding.project_tracked_context&.id == tracked_context&.id
        end
      end

      # This method tries to find an existing finding by signatures
      # in case if a new algorithm is introduced or if there is a finding
      # with the UUID calculated by the location information.
      def existing_findings_by_signature(finding)
        signature_keys = # Sorting order is from highest priority to lowest priority algorithm:
          #  gives precedence to algorithm with better deduplication performance.
          finding.signatures.sort_by { |sig| -sig.priority }.map(&:signature_hex)

        existing_signatures.values_at(*signature_keys).compact.map(&:finding).select do |existing_finding|
          compare_with_existing_finding(existing_finding, finding)
        end
      end

      # This method should be called when a project starts using
      # the finding signatures for the first time.
      def existing_findings_by_location(finding)
        return [] unless finding.has_signatures? && finding.location

        all_existing_findings_by_location[finding.location.fingerprint].to_a.select do |existing_finding|
          compare_with_existing_finding(existing_finding, finding)
        end
      end

      def compare_with_existing_finding(existing_finding, finding)
        existing_finding.primary_identifier&.fingerprint == finding.primary_identifier_fingerprint &&
          existing_finding.scanner == scanners[finding.scanner.external_id]
      end

      def existing_signatures
        @existing_signatures ||= ::Vulnerabilities::FindingSignature.by_signature_sha(finding_signature_shas)
            .by_project(project)
            .eager_load_comparison_entities
            .index_by(&:signature_hex)
      end

      def finding_signature_shas
        @finding_signature_shas ||= findings.flat_map(&:signatures).map(&:signature_sha)
      end

      def all_existing_findings_by_location
        @all_existing_findings_by_location ||= project.vulnerability_findings
                                                  .by_report_types([report_type])
                                                  .by_location_fingerprints(location_fingerprints)
                                                  .eager_load_comparison_entities
                                                  .group_by(&:location_fingerprint)
      end

      def location_fingerprints
        findings.map(&:location).compact.map(&:fingerprint)
      end

      def report_type
        findings.first&.report_type
      end
    end

    private

    attr_reader :security_report, :known_uuids, :context_unaware_uuids, :signatures_enabled

    delegate :pipeline, :findings, :type, :has_signatures?, :tracked_context, to: :security_report, private: true
    delegate :project, to: :pipeline, private: true

    def existing_scanners
      # Reloading the scanners will make sure that the collection proxy will be up-to-date.
      @existing_scanners ||= project.vulnerability_scanners.reset.index_by(&:external_id)
    end

    def override_uuids?
      signatures_enabled && has_signatures?
    end
  end
end
