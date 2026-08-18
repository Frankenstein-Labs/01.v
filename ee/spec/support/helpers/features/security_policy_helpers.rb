# frozen_string_literal: true

module Features
  module SecurityPolicyHelpers
    include RepoHelpers

    private

    def create_policy_setup
      stub_licensed_features(security_dashboard: true,
        multiple_approval_rules: true,
        sast: true, report_approver_rules: true,
        security_orchestration_policies: true)

      config = create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)

      create_and_delete_files(policy_management_project, { '.gitlab/security-policies/policy.yml' => policy_yaml }) do
        Security::SyncScanPoliciesWorker.new.perform(config.id, 'force_resync' => true)
      end
    end

    def policy_yaml
      raise NotImplementedError, "#{self.class}##{__method__} must be defined in the including spec"
    end
  end
end
