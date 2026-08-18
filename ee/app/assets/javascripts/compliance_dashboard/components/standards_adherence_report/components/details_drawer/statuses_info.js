import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL } from '~/constants';

export const statusesInfo = {
  scanner_sast_running: {
    title: s__('ComplianceStandardsAdherence|SAST running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures Static Application Security Testing (SAST) is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure SAST scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Set up SAST in your CI/CD pipeline to automatically detect code vulnerabilities.',
        ),
        linkTitle: __('SAST configuration'),
        ultimate: false,
        link: helpPagePath('user/application_security/sast/_index.md'),
      },
    ],
  },
  minimum_approvals_required_1: {
    title: s__('ComplianceStandardsAdherence|At least one approval'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that merge requests require at least one approval before merging.',
    ),
    projectSettingsPath: '/-/settings/merge_requests',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure approval requirements'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to require at least one approval on merge requests to improve code quality and security.',
        ),
        linkTitle: __('Merge request approvals'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/approvals/_index.md'),
      },
    ],
  },
  minimum_approvals_required_2: {
    title: s__('ComplianceStandardsAdherence|At least two approvals'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that merge requests require at least two approvals before merging.',
    ),
    projectSettingsPath: '/-/settings/merge_requests',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure approval requirements'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to require at least two approvals on merge requests to improve code quality and security.',
        ),
        linkTitle: __('Merge request approvals'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/approvals/_index.md'),
      },
    ],
  },
  merge_request_prevent_author_approval: {
    title: s__('ComplianceStandardsAdherence|Author approved merge request is forbidden'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that the author of a merge request cannot approve their own changes.',
    ),
    projectSettingsPath: '/-/settings/merge_requests',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Prevent author approvals'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project settings to prevent merge request authors from approving their own changes.',
        ),
        linkTitle: __('Merge request approvals'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/approvals/_index.md'),
      },
    ],
  },
  merge_request_prevent_committers_approval: {
    title: s__('ComplianceStandardsAdherence|Committers approved merge request is forbidden'),
    description: s__(
      'ComplianceStandardsAdherence|Prevents users who have committed to a merge request from approving it.',
    ),
    projectSettingsPath: '/-/settings/merge_requests',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Prevent committer approvals'),
        description: s__(
          'ComplianceStandardsAdherence|Update your approval settings to prevent committers from approving merge requests containing their commits.',
        ),
        linkTitle: __('Merge request approvals'),
        ultimate: true,
        link: helpPagePath('user/project/merge_requests/approvals/_index.md'),
      },
    ],
  },
  project_visibility_not_internal: {
    title: s__('ComplianceStandardsAdherence|Internal visibility is forbidden'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures projects are not set to internal visibility.',
    ),
    projectSettingsPath: '/-/edit',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Update project visibility'),
        description: s__(
          'ComplianceStandardsAdherence|Change your project visibility settings to comply with organizational security requirements.',
        ),
        linkTitle: __('Project visibility'),
        ultimate: false,
        link: helpPagePath('user/public_access.md'),
      },
    ],
  },
  default_branch_protected: {
    title: s__('ComplianceStandardsAdherence|Default branch protected'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures the default branch has protection rules enabled.',
    ),
    projectSettingsPath: '/-/settings/repository',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up branch protection'),
        description: s__(
          'ComplianceStandardsAdherence|Set up branch protection rules for your default branch to enforce quality standards.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  auth_sso_enabled: {
    title: s__('ComplianceStandardsAdherence|Auth SSO enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures Single Sign-On (SSO) authentication is enabled for the project.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable SSO authentication'),
        description: s__(
          'ComplianceStandardsAdherence|Set up Single Sign-On authentication to improve security and user management.',
        ),
        linkTitle: __('SSO for GitLab.com groups'),
        ultimate: true,
        link: helpPagePath('user/group/saml_sso/_index.md'),
      },
    ],
  },
  scanner_secret_detection_running: {
    title: s__('ComplianceStandardsAdherence|Secret detection running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures secret detection scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement secret detection'),
        description: s__(
          'ComplianceStandardsAdherence|Implement secret detection scanning in your CI/CD pipeline to identify and remove exposed credentials.',
        ),
        linkTitle: __('Secret detection'),
        ultimate: true,
        link: helpPagePath('user/application_security/secret_detection/_index.md'),
      },
    ],
  },
  scanner_dep_scanning_running: {
    title: s__('ComplianceStandardsAdherence|Dependency scanning running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures dependency scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable dependency scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Enable dependency scanning to automatically detect vulnerable libraries in your application.',
        ),
        linkTitle: __('Dependency scanning'),
        ultimate: false,
        link: helpPagePath('user/application_security/dependency_scanning/_index.md'),
      },
    ],
  },
  scanner_container_scanning_running: {
    title: s__('ComplianceStandardsAdherence|Container scanning running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures container scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up container scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Set up container scanning in your pipeline to identify vulnerabilities in your container images.',
        ),
        linkTitle: __('Container scanning'),
        ultimate: true,
        link: helpPagePath('user/application_security/container_scanning/_index.md'),
      },
    ],
  },
  scanner_license_compliance_running: {
    title: s__('ComplianceStandardsAdherence|License compliance running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures license compliance scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable license compliance scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Set up license compliance scanning to identify potentially problematic open source licenses.',
        ),
        linkTitle: __('License compliance'),
        ultimate: true,
        link: helpPagePath('user/compliance/license_approval_policies.md'),
      },
    ],
  },
  scanner_dast_running: {
    title: s__('ComplianceStandardsAdherence|DAST running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures Dynamic Application Security Testing (DAST) is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure DAST scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Configure DAST in your CI/CD pipeline to automatically test your application for security issues.',
        ),
        linkTitle: __('DAST configuration'),
        ultimate: false,
        link: helpPagePath('user/application_security/dast/_index.md'),
      },
    ],
  },
  scanner_api_security_running: {
    title: s__('ComplianceStandardsAdherence|API security running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures API security scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement API security testing'),
        description: s__(
          'ComplianceStandardsAdherence|Implement API security testing to protect your application interfaces from attacks.',
        ),
        linkTitle: __('API security'),
        ultimate: true,
        link: helpPagePath('user/application_security/api_security/_index.md'),
      },
    ],
  },
  scanner_code_quality_running: {
    title: s__('ComplianceStandardsAdherence|Code quality running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures code quality scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable code quality scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Enable code quality scanning to improve code maintainability and reduce technical debt.',
        ),
        linkTitle: __('Code quality'),
        ultimate: false,
        link: helpPagePath('ci/testing/code_quality.md'),
      },
    ],
  },
  scanner_iac_running: {
    title: s__('ComplianceStandardsAdherence|IaC scanning running'),
    description: s__(
      "ComplianceStandardsAdherence|Ensures Infrastructure as Code (IaC) scanning is configured and running in the project's default branch pipeline.",
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up IaC scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Configure Infrastructure as Code scanning to detect misconfigurations before deployment.',
        ),
        linkTitle: __('IaC security'),
        ultimate: true,
        link: helpPagePath('user/application_security/iac_scanning/_index.md'),
      },
    ],
  },
  code_changes_requires_code_owners: {
    title: s__('ComplianceStandardsAdherence|Code changes require code owners'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures code changes require approval from code owners.',
    ),
    projectSettingsPath: '/-/settings/repository',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up code owners'),
        description: s__(
          'ComplianceStandardsAdherence|Configure code owners to ensure appropriate review of specific code sections.',
        ),
        linkTitle: __('Code owners'),
        ultimate: false,
        link: helpPagePath('user/project/codeowners/_index.md'),
      },
    ],
  },
  reset_approvals_on_push: {
    title: s__('ComplianceStandardsAdherence|Reset approvals on push'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures approvals are reset when new commits are pushed to the merge request.',
    ),
    projectSettingsPath: '/-/settings/merge_requests',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable reset approvals on push'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to reset approvals when new changes are pushed.',
        ),
        linkTitle: __('Reset approvals on push'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/approvals/settings.md'),
      },
    ],
  },
  status_checks_required: {
    title: s__('ComplianceStandardsAdherence|Status checks required'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures status checks must pass before merging is allowed.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure status checks'),
        description: s__(
          'ComplianceStandardsAdherence|Set up required status checks to ensure code quality before merging.',
        ),
        linkTitle: __('Status checks'),
        ultimate: true,
        link: helpPagePath('user/project/merge_requests/status_checks.md'),
      },
    ],
  },
  require_branch_up_to_date: {
    title: s__('ComplianceStandardsAdherence|Require branch up to date'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures the source branch is up to date with the target branch before merging.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure branch update requirements'),
        description: s__(
          'ComplianceStandardsAdherence|Set up requirements for branches to be up to date before merging.',
        ),
        linkTitle: __('Merge requests'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/methods/_index.md'),
      },
    ],
  },
  resolve_discussions_required: {
    title: s__('ComplianceStandardsAdherence|Resolve discussions required'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures all discussions must be resolved before merging is allowed.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Require resolved discussions'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to require all discussions be resolved before merging.',
        ),
        linkTitle: __('Resolve discussions'),
        ultimate: false,
        link: helpPagePath('user/discussions/_index.md'),
      },
    ],
  },
  require_linear_history: {
    title: s__('ComplianceStandardsAdherence|Require linear history'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures a linear commit history by forbidding merge commits.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure linear history'),
        description: s__(
          'ComplianceStandardsAdherence|Set up your project to maintain a clean, linear commit history.',
        ),
        linkTitle: __('Merge request fast-forward merges'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/methods/_index.md', {
          anchor: 'fast-forward-merge',
        }),
      },
    ],
  },
  restrict_push_merge_access: {
    title: s__('ComplianceStandardsAdherence|Restrict push/merge access'),
    description: s__(
      'ComplianceStandardsAdherence|Restricts who can push to or merge into protected branches.',
    ),
    projectSettingsPath: '/-/settings/repository',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure access restrictions'),
        description: s__(
          'ComplianceStandardsAdherence|Set up branch protection rules to restrict push and merge access to protected branches.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  force_push_disabled: {
    title: s__('ComplianceStandardsAdherence|Force push disabled'),
    description: s__('ComplianceStandardsAdherence|Prevents force pushing to repositories.'),
    projectSettingsPath: '/-/settings/repository',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Disable force pushing'),
        description: s__(
          'ComplianceStandardsAdherence|Configure branch protection to prevent force pushes to repository branches.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  terraform_enabled: {
    title: s__('ComplianceStandardsAdherence|Terraform enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures Terraform integration is enabled for the project.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable Terraform integration'),
        description: s__(
          'ComplianceStandardsAdherence|Set up Terraform integration for your project to manage infrastructure as code.',
        ),
        linkTitle: __('Terraform in GitLab'),
        ultimate: true,
        link: helpPagePath('administration/terraform_state.md'),
      },
    ],
  },
  project_repo_exists: {
    title: s__('ComplianceStandardsAdherence|Project repository exists'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that a Git repository exists for the project.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Project repository exists'),
        description: s__(
          'ComplianceStandardsAdherence|Ensure version control is properly configured for your project.',
        ),
        linkTitle: __('Git in GitLab'),
        ultimate: false,
        link: helpPagePath('topics/git/_index.md'),
      },
    ],
  },
  issue_tracking_enabled: {
    title: s__('ComplianceStandardsAdherence|Issue tracking enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures issue tracking functionality is enabled for the project.',
    ),
    projectSettingsPath: '/-/edit',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable issue tracking'),
        description: s__(
          'ComplianceStandardsAdherence|Configure issue tracking to organize and prioritize project work.',
        ),
        linkTitle: __('GitLab issues'),
        ultimate: false,
        link: helpPagePath('user/project/issues/_index.md'),
      },
    ],
  },
  stale_branch_cleanup_enabled: {
    title: s__('ComplianceStandardsAdherence|Stale branch cleanup enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures automatic cleanup of stale branches is enabled.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable stale branch cleanup'),
        description: s__(
          'ComplianceStandardsAdherence|Set up automatic cleanup of stale branches to maintain repository hygiene.',
        ),
        linkTitle: __('Deleting branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/_index.md'),
      },
    ],
  },
  branch_deletion_disabled: {
    title: s__('ComplianceStandardsAdherence|Branch deletion disabled'),
    description: s__('ComplianceStandardsAdherence|Prevents deletion of branches.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Disable branch deletion'),
        description: s__(
          'ComplianceStandardsAdherence|Configure branch protection to prevent accidental or unauthorized branch deletion.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  review_and_archive_stale_repos: {
    title: s__('ComplianceStandardsAdherence|Review and archive stale repositories'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures stale repositories are reviewed and archived.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement repository review process'),
        description: s__(
          'ComplianceStandardsAdherence|Establish a process to periodically review and archive inactive repositories.',
        ),
        linkTitle: __('Archiving projects'),
        ultimate: false,
        link: helpPagePath('user/project/settings/_index.md'),
      },
    ],
  },
  review_and_remove_inactive_users: {
    title: s__('ComplianceStandardsAdherence|Review and remove inactive users'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures inactive users are reviewed and removed.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement user review process'),
        description: s__(
          'ComplianceStandardsAdherence|Establish a process to periodically review and remove inactive users.',
        ),
        linkTitle: __('Managing users'),
        ultimate: true,
        link: helpPagePath('administration/admin_area.md'),
      },
    ],
  },
  more_members_than_admins: {
    title: s__('ComplianceStandardsAdherence|More members than admins'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures fewer administrators are assigned to the project than total members.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Add adequate administrators'),
        description: s__(
          'ComplianceStandardsAdherence|Ensure your project has an appropriate number of administrators assigned.',
        ),
        linkTitle: __('Project members'),
        ultimate: false,
        link: helpPagePath('user/project/members/_index.md'),
      },
    ],
  },
  require_mfa_for_contributors: {
    title: s__('ComplianceStandardsAdherence|Require MFA for contributors'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures contributors have Multi-Factor Authentication enabled.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enforce MFA for contributors'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to require all contributors to use Multi-Factor Authentication.',
        ),
        linkTitle: __('MFA for contributors'),
        ultimate: true,
        link: helpPagePath('user/profile/account/two_factor_authentication.md'),
      },
    ],
  },
  require_mfa_at_org_level: {
    title: s__('ComplianceStandardsAdherence|Require MFA at organization level'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures Multi-Factor Authentication is required at the organization level.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable organization-wide MFA'),
        description: s__(
          'ComplianceStandardsAdherence|Configure organization settings to require Multi-Factor Authentication for all users.',
        ),
        linkTitle: __('Group-level MFA enforcement'),
        ultimate: true,
        link: helpPagePath('user/profile/account/two_factor_authentication.md'),
      },
    ],
  },
  ensure_2_admins_per_repo: {
    title: s__('ComplianceStandardsAdherence|Ensure two administrators per repository'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures at least two administrators are assigned to each repository.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Add multiple administrators'),
        description: s__(
          'ComplianceStandardsAdherence|Ensure each repository has at least two administrators assigned for redundancy.',
        ),
        linkTitle: __('Project members'),
        ultimate: false,
        link: helpPagePath('user/project/members/_index.md'),
      },
    ],
  },
  strict_permissions_for_repo: {
    title: s__('ComplianceStandardsAdherence|Strict Permission for Repository'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures strict permissions are set for repository access.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure strict permissions'),
        description: s__(
          'ComplianceStandardsAdherence|Set up strict permission controls for repository access.',
        ),
        linkTitle: __('Project members permissions'),
        ultimate: true,
        link: helpPagePath('user/permissions.md'),
      },
    ],
  },
  secure_webhooks: {
    title: s__('ComplianceStandardsAdherence|Secure webhooks'),
    description: s__('ComplianceStandardsAdherence|Ensures webhooks are securely configured.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Secure webhook configurations'),
        description: s__(
          'ComplianceStandardsAdherence|Review and secure all webhook configurations to prevent unauthorized access.',
        ),
        linkTitle: __('Webhooks'),
        ultimate: false,
        link: helpPagePath('user/project/integrations/webhooks.md'),
      },
    ],
  },
  restricted_build_access: {
    title: s__('ComplianceStandardsAdherence|Restricted build access'),
    description: s__(
      'ComplianceStandardsAdherence|Restricts access to build artifacts and pipeline outputs.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Restrict pipeline access'),
        description: s__(
          'ComplianceStandardsAdherence|Configure access controls to limit who can access build artifacts and outputs.',
        ),
        linkTitle: __('Pipeline security'),
        ultimate: true,
        link: helpPagePath('ci/pipelines/settings.md'),
      },
    ],
  },
  gitlab_license_level_ultimate: {
    title: s__('ComplianceStandardsAdherence|GitLab license level Ultimate'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures the GitLab instance is using an Ultimate license level.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Upgrade to Ultimate license'),
        description: s__(
          'ComplianceStandardsAdherence|Upgrade your GitLab license to Ultimate to access all security and compliance features.',
        ),
        linkTitle: __('GitLab licensing'),
        ultimate: true,
        link: `${PROMO_URL}/pricing/feature-comparison/`,
      },
    ],
  },
  status_page_configured: {
    title: s__('ComplianceStandardsAdherence|Status page configured'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures a status page is configured for the project.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure status page'),
        description: s__(
          'ComplianceStandardsAdherence|Set up a status page to communicate project availability and incidents.',
        ),
        linkTitle: __('Status page'),
        ultimate: true,
        link: helpPagePath('operations/incident_management/status_page.md'),
      },
    ],
  },
  has_valid_ci_config: {
    title: s__('ComplianceStandardsAdherence|Has valid CI/CD configuration'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures the project has a valid CI/CD configuration.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Create valid CI configuration'),
        description: s__(
          'ComplianceStandardsAdherence|Set up a properly configured CI/CD pipeline for your project.',
        ),
        linkTitle: __('CI/CD pipeline configuration'),
        ultimate: false,
        link: helpPagePath('ci/yaml/_index.md'),
      },
    ],
  },
  error_tracking_enabled: {
    title: s__('ComplianceStandardsAdherence|Error tracking enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures error tracking is enabled for the project.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable error tracking'),
        description: s__(
          'ComplianceStandardsAdherence|Set up error tracking to monitor and address application errors.',
        ),
        linkTitle: __('Error tracking'),
        ultimate: false,
        link: helpPagePath('operations/error_tracking.md'),
      },
    ],
  },
  default_branch_users_can_push: {
    title: s__('ComplianceStandardsAdherence|Default branch users can push'),
    description: s__(
      'ComplianceStandardsAdherence|Controls whether users can push directly to the default branch.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure push permissions'),
        description: s__(
          'ComplianceStandardsAdherence|Adjust permissions to control who can push directly to the default branch.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  default_branch_protected_from_direct_push: {
    title: s__('ComplianceStandardsAdherence|Default branch protected from direct push'),
    description: s__('ComplianceStandardsAdherence|Prevents direct pushes to the default branch.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable branch protection'),
        description: s__(
          'ComplianceStandardsAdherence|Configure branch protection to prevent direct pushes to the default branch.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  push_protection_enabled: {
    title: s__('ComplianceStandardsAdherence|Push protection enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures push protection is enabled for sensitive files.',
    ),
    projectSettingsPath: '/-/settings/repository',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable push protection'),
        description: s__(
          'ComplianceStandardsAdherence|Configure push rules to prevent sensitive information from being committed.',
        ),
        linkTitle: __('Push rules'),
        ultimate: true,
        link: helpPagePath('user/project/repository/push_rules.md'),
      },
    ],
  },
  project_marked_for_deletion: {
    title: s__('ComplianceStandardsAdherence|Project not marked for deletion'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that project is not marked for deletion.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Review project status'),
        description: s__(
          'ComplianceStandardsAdherence|Review and update the project status to ensure it is not marked for deletion.',
        ),
        linkTitle: __('Project settings'),
        ultimate: false,
        link: helpPagePath('user/project/settings/_index.md'),
      },
    ],
  },
  project_archived: {
    title: s__('ComplianceStandardsAdherence|Project not archived'),
    description: s__('ComplianceStandardsAdherence|Ensures that project is not archived.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Review archive status'),
        description: s__(
          'ComplianceStandardsAdherence|Review the project archive status and unarchive if necessary for active projects.',
        ),
        linkTitle: __('Archiving projects'),
        ultimate: false,
        link: helpPagePath('user/project/settings/_index.md'),
      },
    ],
  },
  default_branch_users_can_merge: {
    title: s__('ComplianceStandardsAdherence|Default branch users can merge'),
    description: s__(
      'ComplianceStandardsAdherence|Controls whether users can merge changes to the default branch.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure merge permissions'),
        description: s__(
          'ComplianceStandardsAdherence|Adjust permissions to control who can merge changes to the default branch.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  merge_request_commit_reset_approvals: {
    title: s__('ComplianceStandardsAdherence|Merge request commit resets approvals'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures new commits to merge requests reset approvals.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable approval reset on commit'),
        description: s__(
          'ComplianceStandardsAdherence|Configure merge requests to reset approvals when new commits are added.',
        ),
        linkTitle: __('Reset approvals on push'),
        ultimate: false,
        link: helpPagePath('user/project/merge_requests/approvals/settings.md'),
      },
    ],
  },
  project_visibility_not_public: {
    title: s__('ComplianceStandardsAdherence|Project visibility not public'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures projects are not set to public visibility.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Update project visibility'),
        description: s__(
          'ComplianceStandardsAdherence|Change your project visibility to private or internal as per security requirements.',
        ),
        linkTitle: __('Project visibility'),
        ultimate: false,
        link: helpPagePath('user/public_access.md'),
      },
    ],
  },
  package_hunter_no_findings_untriaged: {
    title: s__('ComplianceStandardsAdherence|Package Hunter no findings untriaged'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures all package hunter findings are triaged.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Triage package hunter findings'),
        description: s__(
          'ComplianceStandardsAdherence|Review and triage all package hunter findings to assess and address potential risks.',
        ),
        linkTitle: __('Package hunter'),
        ultimate: true,
        link: helpPagePath('user/application_security/triage/_index.md'),
      },
    ],
  },
  project_pipelines_not_public: {
    title: s__('ComplianceStandardsAdherence|Project pipelines not public'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures project pipelines are not publicly visible.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Restrict pipeline visibility'),
        description: s__(
          'ComplianceStandardsAdherence|Configure pipeline settings to restrict public access to CI/CD pipelines.',
        ),
        linkTitle: __('Pipeline settings'),
        ultimate: false,
        link: helpPagePath('ci/pipelines/settings.md'),
      },
    ],
  },
  vulnerabilities_slo_days_over_threshold: {
    title: s__('ComplianceStandardsAdherence|Vulnerabilities SLO days over threshold'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures vulnerabilities are addressed within SLO thresholds.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement vulnerability SLOs'),
        description: s__(
          'ComplianceStandardsAdherence|Set up Service Level Objectives for addressing identified vulnerabilities within defined timeframes.',
        ),
        linkTitle: __('Vulnerability management'),
        ultimate: true,
        link: helpPagePath('user/application_security/vulnerabilities/_index.md'),
      },
    ],
  },
  merge_requests_approval_rules_prevent_editing: {
    title: s__('ComplianceStandardsAdherence|Merge requests approval rules prevent editing'),
    description: s__(
      'ComplianceStandardsAdherence|Prevents editing of merge request approval rules.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Lock approval rules'),
        description: s__(
          'ComplianceStandardsAdherence|Configure settings to prevent editing of merge request approval rules.',
        ),
        linkTitle: __('Merge request approvals settings'),
        ultimate: true,
        link: helpPagePath('user/project/merge_requests/approvals/settings.md'),
      },
    ],
  },
  project_user_defined_variables_restricted_to_maintainers: {
    title: s__(
      'ComplianceStandardsAdherence|User-defined CI/CD variables restricted to maintainers',
    ),
    description: s__(
      'ComplianceStandardsAdherence|User-defined CI/CD variables restricted to maintainers.',
    ),
    projectSettingsPath: '/-/settings/ci_cd',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Restrict variable creation'),
        description: s__(
          'ComplianceStandardsAdherence|Configure settings to ensures that only users with the maintainer role or higher can pass user-defined variables when triggering pipelines.',
        ),
        linkTitle: __('Project CI/CD variables'),
        ultimate: false,
        link: helpPagePath('ci/variables/_index.md'),
      },
    ],
  },
  merge_requests_require_code_owner_approval: {
    title: s__('ComplianceStandardsAdherence|Merge requests require code owner approval'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures merge requests require approval from code owners.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Require code owner approval'),
        description: s__(
          'ComplianceStandardsAdherence|Configure merge requests to require approval from designated code owners.',
        ),
        linkTitle: __('Code owners'),
        ultimate: true,
        link: helpPagePath('user/project/codeowners/_index.md'),
      },
    ],
  },
  cicd_job_token_scope_enabled: {
    title: s__('ComplianceStandardsAdherence|CI/CD job token scope enabled'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures CI/CD job token scope restrictions are enabled.',
    ),
    projectSettingsPath: '/-/settings/ci_cd',
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure job token scope'),
        description: s__(
          'ComplianceStandardsAdherence|Set up CI/CD job token scope restrictions to enhance pipeline security.',
        ),
        linkTitle: __('CI/CD job token'),
        ultimate: true,
        link: helpPagePath('ci/jobs/ci_job_token.md'),
      },
    ],
  },
  protected_branches_set: {
    title: s__('ComplianceStandardsAdherence|Protected branches exist'),
    description: s__(
      'ComplianceStandardsAdherence|Ensures that project contains protected branches.',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up branch protection'),
        description: s__(
          'ComplianceStandardsAdherence|Set up branch protection rules for your default branch to enforce quality standards.',
        ),
        linkTitle: __('Protected branches'),
        ultimate: false,
        link: helpPagePath('user/project/repository/branches/protected.md'),
      },
    ],
  },
  code_owner_approval_required: {
    title: s__('ComplianceStandardsAdherence|Code owner approval required'),
    description: s__('ComplianceStandardsAdherence|Ensures that code owners file is configured.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enforce code owner approval'),
        description: s__(
          'ComplianceStandardsAdherence|Configure code owners to require approval for code changes.',
        ),
        linkTitle: __('Code owners'),
        ultimate: false,
        link: helpPagePath('user/project/codeowners/_index.md'),
      },
    ],
  },
  require_signed_commits: {
    title: s__('ComplianceStandardsAdherence|Requires signed commits'),
    description: s__('ComplianceStandardsAdherence|Ensures that signed commits are required'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure push rules to reject unsigned commits.'),
        description: s__(
          'ComplianceStandardsAdherence|Configure push rules to require that all commits are signed.',
        ),
        linkTitle: __('Code owners'),
        ultimate: false,
        link: helpPagePath('user/project/repository/signed_commits/_index.md'),
      },
    ],
  },
  has_forks: {
    title: s__('ComplianceStandardsAdherence|Forks exist for the project'),
    description: s__('ComplianceStandardsAdherence|Ensures that the project has been forked.'),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Create a fork of the project.'),
        description: s__('ComplianceStandardsAdherence|Create a fork of the project.'),
        linkTitle: __('Code owners'),
        ultimate: false,
        link: helpPagePath('user/project/repository/forking_workflow.md'),
      },
    ],
  },
};
