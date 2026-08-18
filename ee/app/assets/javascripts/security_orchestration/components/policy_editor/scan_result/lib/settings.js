import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const BLOCK_BRANCH_MODIFICATION = 'block_branch_modification';
export const BLOCK_GROUP_BRANCH_MODIFICATION = 'block_group_branch_modification';
export const PREVENT_PUSHING_AND_FORCE_PUSHING = 'prevent_pushing_and_force_pushing';
export const PREVENT_APPROVAL_BY_AUTHOR = 'prevent_approval_by_author';
export const PREVENT_APPROVAL_BY_COMMIT_AUTHOR = 'prevent_approval_by_commit_author';
export const REMOVE_APPROVALS_WITH_NEW_COMMIT = 'remove_approvals_with_new_commit';
export const REQUIRE_PASSWORD_TO_APPROVE = 'require_password_to_approve';
export const PREVENT_EDITING_APPROVAL_RULES = 'prevent_editing_approval_rules';

// This defines behavior for existing policies. They shouldn't automatically opt-in to use this setting.
export const protectedBranchesConfiguration = {
  [BLOCK_BRANCH_MODIFICATION]: false,
};

// This defines behavior for existing policies. They shouldn't automatically opt-in to use this setting.
export const groupProtectedBranchesConfiguration = (blockBranchModificationValue = false) => ({
  [BLOCK_GROUP_BRANCH_MODIFICATION]: blockBranchModificationValue,
});

// This defines behavior for existing policies. They shouldn't automatically opt-in to use this setting.
export const pushingBranchesConfiguration = {
  [PREVENT_PUSHING_AND_FORCE_PUSHING]: false,
};

export const PROTECTED_BRANCHES_CONFIGURATION_KEYS = [
  BLOCK_BRANCH_MODIFICATION,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
];

export const MERGE_REQUEST_CONFIGURATION_KEYS = [
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
];

export const PROJECT_WIDE_CONFIGURATION_KEYS = [PREVENT_EDITING_APPROVAL_RULES];

export const PROJECT_LEVEL_CONFIGURATION_KEYS = [
  ...MERGE_REQUEST_CONFIGURATION_KEYS,
  ...PROJECT_WIDE_CONFIGURATION_KEYS,
];

// This defines behavior for existing policies. They shouldn't automatically opt-in to use this setting.
export const mergeRequestConfiguration = {
  [PREVENT_APPROVAL_BY_AUTHOR]: false,
  [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: false,
  [REMOVE_APPROVALS_WITH_NEW_COMMIT]: false,
  [PREVENT_EDITING_APPROVAL_RULES]: false,
  [REQUIRE_PASSWORD_TO_APPROVE]: false,
};

export const BLOCK_GROUP_BRANCH_MODIFICATION_WITH_EXCEPTIONS_HUMANIZED_STRING = s__(
  'ScanResultPolicy|Prevent %{linkStart}group branch%{linkEnd} modification %{exceptSelection} %{groupSelection}',
);
export const BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING = s__(
  'ScanResultPolicy|Prevent %{linkStart}group branch%{linkEnd} modification %{exceptSelection}',
);

export const SETTINGS_HUMANIZED_STRINGS = {
  [BLOCK_BRANCH_MODIFICATION]: s__('ScanResultPolicy|Prevent branch modification'),
  [BLOCK_GROUP_BRANCH_MODIFICATION]: s__('ScanResultPolicy|Prevent group branch modification'),
  [PREVENT_PUSHING_AND_FORCE_PUSHING]: s__('ScanResultPolicy|Prevent pushing and force pushing'),
  [PREVENT_APPROVAL_BY_AUTHOR]: s__("ScanResultPolicy|Prevent approval by merge request's author"),
  [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: s__('ScanResultPolicy|Prevent approval by commit author'),
  [REMOVE_APPROVALS_WITH_NEW_COMMIT]: s__('ScanResultPolicy|Remove all approvals with new commit'),
  [REQUIRE_PASSWORD_TO_APPROVE]: s__(
    'ScanResultPolicy|Require user re-authentication (password or SAML) to approve',
  ),
  [PREVENT_EDITING_APPROVAL_RULES]: s__(
    'ScanResultPolicy|Prevent editing approval rules on merge requests',
  ),
};

export const SETTINGS_TOOLTIP = {
  [BLOCK_BRANCH_MODIFICATION]: s__(
    'ScanResultPolicy|When enabled, prevents a user from removing a branch from the project protected branches list, deleting a protected branch, or changing the default branch if that branch is included in the security policy.',
  ),
  [BLOCK_GROUP_BRANCH_MODIFICATION]: s__(
    'ScanResultPolicy|When enabled, prevents a user from removing a branch from the group protected branches list, deleting a protected branch, or changing the default branch if that branch is included in the security policy.',
  ),
  [PREVENT_PUSHING_AND_FORCE_PUSHING]: s__(
    'ScanResultPolicy|When enabled, prevents pushing and force pushing to a protected branch if that branch is included in the security policy.',
  ),
  [PREVENT_APPROVAL_BY_AUTHOR]: s__(
    'ScanResultPolicy|When enabled, merge request authors cannot approve their own MRs.',
  ),
  [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: s__(
    'ScanResultPolicy|When enabled, users who have contributed code to the MR are ineligible for approval.',
  ),
  [REMOVE_APPROVALS_WITH_NEW_COMMIT]: s__(
    'ScanResultPolicy|When enabled, if an MR receives all necessary approvals to merge, but then a new commit is added, new approvals are required.',
  ),
  [REQUIRE_PASSWORD_TO_APPROVE]: s__(
    'ScanResultPolicy|When enabled, there will be password confirmation on approvals.',
  ),
  [PREVENT_EDITING_APPROVAL_RULES]: s__(
    'ScanResultPolicy|When enabled, prevents users from overriding approval rules on merge requests in projects where this policy applies.',
  ),
};

export const SETTINGS_POPOVER_STRINGS = {
  [BLOCK_BRANCH_MODIFICATION]: {
    title: s__('ScanResultPolicy|Recommended settings'),
    description: s__(
      "ScanResultPolicy|You have selected all protected branches in this policy's rules. To better protect your project, you should leave this setting enabled. %{linkStart}What are the risks of allowing pushing and force pushing?%{linkEnd}",
    ),
    featureName: 'security_policy_protected_branch_modification',
  },
};

export const SETTINGS_LINKS = {
  [BLOCK_BRANCH_MODIFICATION]: helpPagePath('/user/project/repository/branches/protected.html'),
};

export const VALID_APPROVAL_SETTINGS = [
  ...PROTECTED_BRANCHES_CONFIGURATION_KEYS,
  ...MERGE_REQUEST_CONFIGURATION_KEYS,
  ...PROJECT_WIDE_CONFIGURATION_KEYS,
];

export const PERMITTED_INVALID_SETTINGS_KEY = 'block_protected_branch_modification';

export const PERMITTED_INVALID_SETTINGS = {
  [PERMITTED_INVALID_SETTINGS_KEY]: {
    enabled: true,
  },
};

/**
 * Build settings based on provided flags, scalable for more flags in future
 * @returns {Object} final settings
 */
const buildConfig = (
  settings,
  { hasLinkedGroups = false, namespaceType = NAMESPACE_TYPES.PROJECT },
) => {
  const baseConfigurations = {
    ...protectedBranchesConfiguration,
  };

  const shouldIncludeGroupConfiguration = isGroup(namespaceType) || hasLinkedGroups;

  if (shouldIncludeGroupConfiguration) {
    Object.assign(
      baseConfigurations,
      groupProtectedBranchesConfiguration(settings[BLOCK_BRANCH_MODIFICATION]),
    );
  }

  return {
    ...baseConfigurations,
    ...pushingBranchesConfiguration,
    ...mergeRequestConfiguration,
  };
};

/**
 * Map dynamic approval settings to defined list and update only enable property
 * @param settings
 * @param options
 * @returns {Object}
 */
export const buildSettingsList = (
  { settings = {}, options = {} } = { settings: {}, options: {} },
) => {
  const configuration = buildConfig(settings, options);

  return Object.keys(configuration).reduce((acc, setting) => {
    const hasEnabledProperty = settings ? setting in settings : false;
    acc[setting] = hasEnabledProperty ? settings[setting] : configuration[setting];
    return acc;
  }, {});
};

export const WITHOUT_EXCEPTIONS = 'without_exceptions';
export const EXCEPT_GROUPS = 'except_groups';

export const EXCEPTION_GROUPS_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without exceptions'),
  [EXCEPT_GROUPS]: s__('SecurityOrchestration|except groups'),
};

export const EXCEPTION_GROUPS_LISTBOX_ITEMS = mapToListboxItems(EXCEPTION_GROUPS_TEXTS);

/**
 * Transforms a group into a standardized group object
 * @param {Object} group - Group to transform
 * @returns {Object}
 */
export const createGroupObject = (group) => {
  const convertedId = getIdFromGraphQLId(group.id);

  return {
    ...group,
    id: convertedId,
    text: group.full_name || group.fullName,
    value: convertedId,
  };
};

/**
 * Organizes groups into existing and to-be-retrieved groups
 * @param {string[]} groupIds - Array of group IDs
 * @param {Object[]} selectedGroups - Currently selected groups
 * @param {Object[]} availableGroups - Available groups to choose from
 * @returns {Object} Object containing existing groups and IDs to retrieve
 */
export const organizeGroups = ({ ids = [], availableGroups = [] }) =>
  ids.reduce(
    (acc, selectedId) => {
      const existingGroup = availableGroups.find(({ id }) => id === selectedId);

      if (existingGroup) {
        acc.existingGroups.push(existingGroup);
      } else {
        acc.groupsToRetrieve.push(selectedId);
      }

      return acc;
    },
    { existingGroups: [], groupsToRetrieve: [] },
  );

export const isProjectLevelSettingOverridden = (setting, value) => {
  return PROJECT_LEVEL_CONFIGURATION_KEYS.includes(setting) && Boolean(value);
};
