# frozen_string_literal: true

module Security
  module ScanResultPolicy
    extend ActiveSupport::Concern

    # Maximum limit that can be set via ApplicationSetting
    POLICIES_LIMIT = 20

    APPROVERS_LIMIT = 300
    APPROVERS_ACTIONS_LIMIT = 5

    APPROVAL_RULES_BATCH_SIZE = 5000

    POLICY_TYPE_NAME = 'Merge request approval policy'
    SCAN_FINDING = 'scan_finding'
    LICENSE_SCANNING = 'license_scanning'
    LICENSE_FINDING = 'license_finding'
    ANY_MERGE_REQUEST = 'any_merge_request'
    REQUIRE_APPROVAL = 'require_approval'
    SEND_BOT_MESSAGE = 'send_bot_message'

    ALLOWED_ROLES = %w[developer maintainer owner].freeze
    VALID_EPSS_SCORE_OPERATORS = %i[greater_than less_than].freeze

    def self.epss_score_valid?(epss_score)
      return false unless epss_score.is_a?(Hash) && epss_score.present?

      epss_score[:operator]&.to_sym&.in?(VALID_EPSS_SCORE_OPERATORS) && epss_score[:value].is_a?(Numeric)
    end

    included do
      has_many :scan_result_policy_reads,
        class_name: 'Security::ScanResultPolicyRead',
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration
      has_many :approval_merge_request_rules,
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration
      has_many :approval_project_rules,
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration

      def delete_scan_result_policy_reads
        self.class.transaction do
          delete_scan_finding_rules
          delete_software_license_policies
          delete_policy_violations

          delete_in_batches(scan_result_policy_reads)
        end
      end

      def delete_scan_result_policy_reads_for_project(project_id)
        scan_result_policy_reads.where(project_id: project_id).delete_all
      end

      def delete_scan_finding_rules
        delete_in_batches(approval_project_rules)
        delete_merge_request_rules
      end

      def delete_merge_request_rules
        approval_merge_request_rules.each_batch(of: APPROVAL_RULES_BATCH_SIZE) do |batch|
          batch.for_unmerged_merge_requests.delete_all
        end
      end

      def delete_scan_finding_rules_for_project(project_id)
        delete_in_batches(approval_project_rules.where(project_id: project_id))
      end

      def delete_merge_request_rules_for_project(project_id)
        approval_merge_request_rules.each_batch(of: APPROVAL_RULES_BATCH_SIZE) do |batch|
          batch.for_unmerged_merge_requests.for_merge_request_project(project_id).delete_all
        end
      end

      def delete_software_license_policies_for_project(project)
        delete_in_batches(
          project
            .software_license_policies
            .where(scan_result_policy_read: scan_result_policy_reads.for_project(project))
        )
      end

      def delete_policy_violations_for_project(project)
        # scan_result_policy_violations does not store security_orchestration_policy_configuration_id
        # so we need to scope them through scan_resul_policy_reads in order to delete through policy_configuration
        delete_in_batches(
          Security::ScanResultPolicyViolation
            .where(scan_result_policy_read: scan_result_policy_reads.for_project(project))
        )
      end

      def applicable_scan_result_policies_with_real_index(project)
        active_policies_count = 0
        active_policy_index = 0
        policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)

        scan_result_policies.each_with_index do |policy, index|
          next unless policy[:enabled]

          active_policies_count += 1
          break if active_policies_count > approval_policies_limit
          next unless policy_scope_checker.policy_applicable?(policy, configuration: self)

          yield(policy, index, active_policy_index)
          active_policy_index += 1
        end
      end

      def active_scan_result_policies
        scan_result_policies&.select { |config| config[:enabled] }&.first(approval_policies_limit)
      end

      def approval_policies_limit
        limit_service.approval_policies_per_configuration_limit
      end

      def applicable_scan_result_policies_for_project(project)
        strong_memoize_with(:applicable_scan_result_policies_for_project, project) do
          policy_scope_checker = ::Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)
          active_scan_result_policies.select do |policy|
            policy_scope_checker.policy_applicable?(policy, configuration: self)
          end
        end
      end

      def scan_result_policies
        policy_by_type(:approval_policy).map.with_index do |policy, index|
          policy.merge(type: 'approval_policy', policy_index: index)
        end
      end

      def delete_in_batches(relation)
        relation.each_batch(order_hint: :updated_at) do |batch|
          delete_batch(batch)
        end
      end

      def delete_batch(batch)
        batch.delete_all
      end

      private

      def delete_software_license_policies
        Security::ScanResultPolicyRead
          .where(security_orchestration_policy_configuration_id: id)
          .each_batch(order_hint: :updated_at) do |batch|
          delete_in_batches(SoftwareLicensePolicy.where(scan_result_policy_id: batch.select(:id)))
        end
      end

      def delete_policy_violations
        Security::ScanResultPolicyRead
          .where(security_orchestration_policy_configuration_id: id)
          .each_batch(order_hint: :updated_at) do |batch|
          delete_in_batches(Security::ScanResultPolicyViolation.where(scan_result_policy_id: batch.select(:id)))
        end
      end
    end
  end
end
