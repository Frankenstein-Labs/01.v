# frozen_string_literal: true

module SCA
  class LicenseCompliance
    include ::Gitlab::Utils::StrongMemoize

    LicenseNotFoundError = Class.new(StandardError)

    SORT_DIRECTION = {
      asc: ->(items) { items },
      desc: ->(items) { items.reverse }
    }.with_indifferent_access

    def initialize(project, pipeline, target_branch = nil)
      @project = project
      @pipeline = pipeline
      @target_branch = target_branch
      @scanner = ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline)
    end

    def policies
      strong_memoize(:policies) do
        unclassified_policies.merge(known_policies).sort.map(&:last)
      end
    end

    def find_policies(detected_only: false, classification: [], sort: { by: :name, direction: :asc })
      record_onboarding_progress

      classifications = Array(classification || [])
      matching_policies = policies.reject do |policy|
        (detected_only && policy.dependencies.none?) ||
          (classifications.present? && !policy.classification.in?(classifications))
      end
      sort_items(items: matching_policies, by: sort&.dig(:by), direction: sort&.dig(:direction))
    end

    def latest_build_for_default_branch
      return if pipeline.blank?

      scanner.latest_build_for_default_branch
    end

    def diff_with(other)
      other_report = other.license_scanning_report
      denied_policies_from_other_report = denied_license_policies_from_report(other_report)

      license_scanning_report_diff(other_report).transform_values do |reported_licenses|
        reported_licenses.map do |reported_license|
          build_policy_with_denied_licenses(denied_policies_from_other_report, reported_license)
        end
      end
    end

    def license_scanning_report
      strong_memoize(:license_scanning_report) do
        scanner.report
      end
    end

    private

    def license_scanning_report_diff(other_report)
      license_scanning_report.diff_with_including_new_dependencies_for_unchanged_licenses(other_report,
        include_version: false)
    end

    attr_reader :project, :pipeline, :target_branch, :scanner

    def license_policies
      strong_memoize(:license_policies) do
        next SoftwareLicensePolicy.none if project.blank?

        project
          .software_license_policies
          .including_scan_result_policy_read
          .including_approval_policy_rule
          .unreachable_limit
      end
    end

    # Constructs license to policy map for licenses from `software_license_policies`
    # directly. They are sorted by `classification` to return denied licenses first.
    def direct_license_policies
      strong_memoize(:direct_license_policies) do
        license_policies.sort_by(&:classification).to_h do |policy|
          software_license = Gitlab::SPDX::Catalogue.latest_active_licenses.find do |license|
            license.id == policy.software_license_spdx_identifier
          end

          license = policy.custom_software_license || software_license

          if license.blank?
            Gitlab::ErrorTracking.track_exception(LicenseNotFoundError.new,
              license_spdx_id: policy.software_license_spdx_identifier,
              project_id: policy.project_id)

            next [nil, nil]
          end

          reported_license = reported_license_by_license_model(license)
          [license.canonical_id, build_policy(reported_license, policy, approval_status(policy))]
        end.compact
      end
    end

    def approval_status(policy)
      return policy.approval_status if policy_applies_to_branch?(policy)

      'allowed'
    end

    # Constructs license to policy map for policy with `match_on_inclusion_license` as false
    # by setting the `approval_status` as denied for all licenses from report except
    # for the one mentioned in the policy.
    def denied_license_policies
      strong_memoize(:denied_license_policies) do
        denied_license_policies_from_report(license_scanning_report)
      end
    end

    def known_policies
      return {} if project.blank?

      strong_memoize(:known_policies) do
        direct_license_policies.merge(denied_license_policies)
      end
    end

    def unclassified_policies
      license_scanning_report.licenses.map do |reported_license|
        next if policy_from_licenses(known_policies, reported_license)

        [reported_license.canonical_id, build_policy(reported_license, nil)]
      end.compact.to_h
    end

    def denied_license_policies_from_report(report)
      return {} unless license_policies.exclusion_allowed.exists?

      report.licenses.map do |reported_license|
        next if policy_from_licenses(direct_license_policies, reported_license)

        [reported_license.canonical_id, build_policy(reported_license, nil, 'denied')]
      end.compact.to_h
    end

    def build_policy_with_denied_licenses(denied_policies, reported_license)
      direct_license_policy = policy_from_licenses(direct_license_policies, reported_license)
      return build_policy(reported_license, direct_license_policy, nil) if direct_license_policy

      denied_license_policy = policy_from_licenses(denied_policies, reported_license)
      approval_status = denied_license_policy ? 'denied' : nil
      build_policy(reported_license, denied_license_policy, approval_status)
    end

    def policy_applies_to_branch?(policy)
      approval_rule = policy.approval_policy_rule
      return false unless approval_rule && target_branch

      approval_rule.policy_applies_to_target_branch?(target_branch, project)
    end

    # When the license found in the report doesn't match any license
    # of the SPDX License List, we need to find it by name explicitly.
    def reported_license_by_license_model(software_license)
      license_scanning_report[software_license.canonical_id] ||
        license_scanning_report.by_license_name(software_license.name&.downcase)
    end

    def policy_from_licenses(licenses_map, license)
      licenses_map[license.id] || licenses_map[license&.name&.downcase]
    end

    def build_policy(reported_license, software_license_policy, approval_status = nil)
      ::SCA::LicensePolicy.new(reported_license, software_license_policy, approval_status)
    end

    def sort_items(items:, by:, direction:, available_attributes: ::SCA::LicensePolicy::ATTRIBUTES)
      attribute = available_attributes[by] || available_attributes[:name]
      direction = SORT_DIRECTION[direction] || SORT_DIRECTION[:asc]
      direction.call(items.sort_by { |item| attribute.call(item) })
    end

    def record_onboarding_progress
      return unless pipeline

      ::Onboarding::Progress.register(pipeline.project.root_namespace, :license_scanning_run)
    end
  end
end
