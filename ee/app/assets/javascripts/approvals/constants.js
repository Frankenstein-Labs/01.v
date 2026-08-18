import { __, s__ } from '~/locale';

export const TYPE_USER = 'user';
export const TYPE_GROUP = 'group';
export const TYPE_HIDDEN_GROUPS = 'hidden_groups';

export const RULE_TYPE_FALLBACK = 'fallback';
export const RULE_TYPE_REGULAR = 'regular';
export const RULE_TYPE_REPORT_APPROVER = 'report_approver';
export const RULE_TYPE_CODE_OWNER = 'code_owner';
export const RULE_TYPE_ANY_APPROVER = 'any_approver';
export const RULE_NAME_ANY_APPROVER = 'All Members';

export const LICENSE_CHECK_NAME = 'License-Check';
export const COVERAGE_CHECK_NAME = 'Coverage-Check';

export const REPORT_TYPE_LICENSE_SCANNING = 'license_scanning';
export const REPORT_TYPE_CODE_COVERAGE = 'code_coverage';

export const APPROVAL_RULE_CONFIGS = {
  [COVERAGE_CHECK_NAME]: {
    title: s__('SecurityApprovals|Coverage-Check'),
    popoverText: s__(
      'SecurityApprovals|A merge request approval is required when test coverage declines.',
    ),
    documentationText: s__('SecurityApprovals|Learn more about Coverage-Check'),
    reportType: REPORT_TYPE_CODE_COVERAGE,
  },
};

export const APPROVAL_SETTINGS_I18N = {
  learnMore: __('Learn more.'),
  approvalSettingsHeader: __('Approval settings'),
  approvalSettingsDescription: __('Define how approval rules are applied to merge requests.'),
  saveChanges: __('Save changes'),
  loadingErrorMessage: s__(
    'ApprovalSettings|There was an error loading merge request approval settings.',
  ),
  savingErrorMessage: s__(
    'ApprovalSettings|There was an error updating merge request approval settings.',
  ),
  savingSuccessMessage: s__('ApprovalSettings|Merge request approval settings have been updated.'),
  lockedByAdmin: s__(
    'ApprovalSettings|This setting is configured at the instance level and can only be changed by an administrator.',
  ),
  lockedByGroupOwner: s__(
    'ApprovalSettings|This setting is configured in %{groupName} and can only be changed in the group settings by an administrator or group owner.',
  ),
  enforcedByPolicy: s__(
    'ApprovalSettings|This setting is enforced by a merge request approval policy.',
  ),
};

export const PROJECT_APPROVAL_SETTINGS_LABELS_I18N = {
  authorApprovalLabel: s__('ApprovalSettings|Prevent approval by merge request creator'),
  preventMrApprovalRuleEditLabel: s__(
    'ApprovalSettings|Prevent editing approval rules in merge requests',
  ),
  preventCommittersApprovalLabel: s__(
    'ApprovalSettings|Prevent approvals by users who add commits',
  ),
  requireUserPasswordLabel: s__(
    'ApprovalSettings|Require user re-authentication (password or SAML) to approve',
  ),
  whenCommitAddedLabel: s__('ApprovalSettings|When a commit is added:'),
  keepApprovalsLabel: s__('ApprovalSettings|Keep approvals'),
  removeApprovalsOnPushLabel: s__('ApprovalSettings|Remove all approvals'),
  selectiveCodeOwnerRemovalsLabel: s__(
    'ApprovalSettings|Remove approvals by Code Owners if their files changed',
  ),
};

export const GROUP_APPROVAL_SETTINGS_LABELS_I18N = {
  ...PROJECT_APPROVAL_SETTINGS_LABELS_I18N,
};

export const APPROVAL_DIALOG_I18N = {
  form: {
    approvalsRequiredLabel: s__('ApprovalRule|Required number of approvals'),
    approvalTypeLabel: s__('ApprovalRule|Approver Type'),
    approversLabel: s__('ApprovalRule|Add approvers'),
    nameLabel: s__('ApprovalRule|Rule name'),
    nameDescription: s__('ApprovalRule|Examples: QA, Security.'),
    protectedBranchLabel: s__('ApprovalRule|Target branch'),
    protectedBranchDescription: __(
      'Apply this approval rule to all branches or a specific protected branch.',
    ),
  },
  validations: {
    approvalsRequiredNegativeNumber: __('Please enter a non-negative number'),
    approvalsRequiredNotNumber: __('Please enter a valid number'),
    approvalsRequiredMinimum: __(
      'Please enter a number greater than %{number} (from the project settings)',
    ),
    approversRequired: __('Please select and add a member'),
    branchesRequired: __('Please select a valid target branch'),
    ruleNameTaken: __('Rule name is already taken.'),
    ruleNameMissing: __('Please provide a name'),
    ruleNameTooLong: __('Please enter a name with less than %{number} characters.'),
  },
};

export const SEARCH_PLACEHOLDER = s__('ApprovalRule|Search users or groups');

export const DROPDOWN_OPTION_PROJECT_GROUPS = s__('ApprovalRule|Search in project groups');

export const DROPDOWN_OPTION_ALL_GROUPS = s__('ApprovalRule|Search in all groups');

export const GROUP_OPTIONS = [DROPDOWN_OPTION_ALL_GROUPS, DROPDOWN_OPTION_PROJECT_GROUPS];

export const TABLE_HEADERS = {
  name: s__('ApprovalRule|Rule'),
  members: s__('ApprovalRule|Approvers'),
  approvalsRequired: s__('ApprovalRule|Approvals required'),
  branches: __('Target branch'),
  actions: __('Actions'),
};
