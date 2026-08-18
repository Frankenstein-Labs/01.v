import { GROUP_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';

export const USER = {
  id: 2,
  name: 'Name 1',
  username: 'name.1',
  avatarUrl: 'https://www.gravatar.com/avatar/1234',
  type: USER_TYPE,
  __typename: 'UserCore',
};

export const GROUP = {
  avatarUrl: null,
  id: 1,
  fullName: 'Name 1',
  fullPath: 'path/to/name-1',
  type: GROUP_TYPE,
};

export const mockDefaultApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed`;

export const mockRoleApproversApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 2
        role_approvers:
          - developer
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockUserApproversApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 2
        user_approvers_ids:
          - ${USER.id}
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockGroupApproversApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    policy_scope:
      projects:
        excluding: []
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 2
        group_approvers_ids:
          - ${GROUP.id}
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      block_group_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockLicenseApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: license_finding
        match_on_inclusion_license: true
        licenses:
          allowed: []
        license_states: []
        branch_type: protected
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockLicenseApprovalWithLicenseExceptionsManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: license_finding
        match_on_inclusion_license: true
        licenses:
          allowed:
            - name: Apache License 1.0
              packages:
                excluding:
                  purls:
                    - 'path:to-purl@12.1.2'
                    - 'path:to-purl@12.1.3'
            - name: Japan Network Information Center License
              packages:
                excluding:
                  purls:
                    - 'path:to-purl@12.1.2'
        license_states: []
        branch_type: protected
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockSecurityApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: scan_finding
        scanners:
          - type: sast
            vulnerabilities_allowed: 0
            severity_levels:
              - critical
              - high
            vulnerability_states:
              - new_needs_triage
            vulnerability_attributes:
              false_positive: false
          - type: secret_detection
            vulnerabilities_allowed: 0
            severity_levels:
              - critical
              - high
            vulnerability_states:
              - new_needs_triage
          - type: dependency_scanning
            vulnerabilities_allowed: 0
            severity_levels:
              - critical
              - high
            vulnerability_states:
              - new_needs_triage
            vulnerability_attributes:
              false_positive: false
              fix_available: true
              known_exploited: true
              epss_score:
                operator: greater_than
                value: 0.1
              enrichment_data_unavailable:
                action: block
        vulnerabilities_allowed: 0
        severity_levels: []
        vulnerability_states: []
        branch_type: protected
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockAnyMergeRequestApprovalManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: any_merge_request
        branch_type: protected
        commits: any
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      prevent_editing_approval_rules: false
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockScanResultObject = fromYaml({
  manifest: mockAnyMergeRequestApprovalManifest,
  type: APPROVAL_POLICY_TYPE,
});
