import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { s__, __ } from '~/locale';
import {
  SAST_SHORT_NAME,
  DAST_SHORT_NAME,
  DEPENDENCY_SCANNING_NAME,
  SECRET_DETECTION_NAME,
  CONTAINER_SCANNING_NAME,
  SAST_IAC_SHORT_NAME,
} from '~/security_configuration/constants';
import {
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_DAST,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
  REPORT_TYPE_API_FUZZING,
  REPORT_TYPE_COVERAGE_FUZZING,
} from '~/vue_shared/security_reports/constants';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const EDITOR_MODE_RULE = 'rule';
export const EDITOR_MODE_YAML = 'yaml';

export const PARSING_ERROR_MESSAGE = s__(
  'SecurityOrchestration|Rule mode is unavailable for this policy. In some cases, we cannot parse the YAML file back into the rules editor.',
);

export const ACTION_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the actions in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);

export const RULES_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the rules in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);

export const CONDITION_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the conditions in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);

export const RULE_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the rules in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);

export const SETTING_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the settings in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);

export const EDITOR_MODES = [
  { value: EDITOR_MODE_RULE, text: s__('SecurityOrchestration|Rule mode') },
  { value: EDITOR_MODE_YAML, text: s__('SecurityOrchestration|.yaml mode') },
];

export const DELETE_MODAL_CONFIG = {
  id: 'delete-modal',
  secondary: {
    text: s__('SecurityOrchestration|Delete policy'),
    attributes: { variant: 'danger' },
  },
  cancel: {
    text: __('Cancel'),
  },
};

export const MATCH_ON_INCLUSION_LICENSE = 'match_on_inclusion_license';

export const DEFAULT_MR_TITLE = s__('SecurityOrchestration|Update security policies');

export const POLICY_RUN_TIME_MESSAGE = s__(
  'SecurityOrchestration|Policy changes may take some time to be applied.',
);

export const POLICY_RUN_TIME_TOOLTIP = s__(
  'SecurityOrchestration|For large groups, there may be a significant delay in applying policy changes to pre-existing merge requests. Policy changes typically apply almost immediately for newly created merge requests.',
);

export const SECURITY_POLICY_ACTIONS = Object.freeze({
  APPEND: 'APPEND',
  REMOVE: 'REMOVE',
  REPLACE: 'REPLACE',
});

export const GRAPHQL_ERROR_MESSAGE = s__(
  'SecurityOrchestration|There was a problem creating the new security policy',
);

export const NO_RULE_MESSAGE = s__('SecurityOrchestration|No rules defined - policy will not run.');

export const ACTIONS = {
  tags: 'TAGS',
  variables: 'VARIABLES',
};

export const INVALID_RULE_MESSAGE = s__(
  'SecurityOrchestration|Invalid branch type detected - rule will not be applied.',
);

export const INVALID_PROTECTED_BRANCHES = s__(
  'SecurityOrchestration|The following branches do not exist on this development project: %{branches}. Please review all protected branches to ensure the values are accurate before updating this policy.',
);
export const ADD_RULE_LABEL = s__('SecurityOrchestration|Add new rule');
export const RULES_LABEL = s__('SecurityOrchestration|Rules');

export const ADD_ACTION_LABEL = s__('SecurityOrchestration|Add new action');
export const ACTIONS_LABEL = s__('SecurityOrchestration|Actions');

export const RULE_IF_LABEL = __('if');
export const RULE_OR_LABEL = __('or');
export const SCOPE_LABEL = s__('SecurityOrchestration|Policy scope');
export const ACTION_AND_LABEL = __('and');

export const RULE_MODE_SCANNERS = {
  [REPORT_TYPE_SAST]: SAST_SHORT_NAME,
  [REPORT_TYPE_SAST_IAC]: SAST_IAC_SHORT_NAME,
  [REPORT_TYPE_DAST]: DAST_SHORT_NAME,
  [REPORT_TYPE_SECRET_DETECTION]: SECRET_DETECTION_NAME,
  [REPORT_TYPE_CONTAINER_SCANNING]: CONTAINER_SCANNING_NAME,
  [REPORT_TYPE_DEPENDENCY_SCANNING]: DEPENDENCY_SCANNING_NAME,
  [REPORT_TYPE_API_FUZZING]: s__('ciReport|API Fuzzing'),
  [REPORT_TYPE_COVERAGE_FUZZING]: s__('ciReport|Coverage Fuzzing'),
};

export const MAX_ALLOWED_RULES_LENGTH = 5;
export const MAX_ALLOWED_APPROVER_ACTION_LENGTH = 5;

export const PRIMARY_POLICY_KEYS = [
  'type',
  'name',
  'description',
  'enabled',
  'policy_scope',
  'metadata',
];

export const SPECIFIC_BRANCHES = {
  id: 'SPECIFIC_BRANCHES',
  text: __('specific protected branches'),
  value: 'SPECIFIC_BRANCHES',
};

export const ALL_BRANCHES = {
  text: __('all branches'),
  value: 'all',
};

export const GROUP_DEFAULT_BRANCHES = {
  text: __('all default branches'),
  value: 'default',
};

export const PROJECT_DEFAULT_BRANCH = {
  text: __('default branch'),
  value: 'default',
};

export const ALL_PROTECTED_BRANCHES = {
  text: __('all protected branches'),
  value: 'protected',
};

export const TARGET_PROTECTED = 'target_protected';

export const TARGET_PROTECTED_BRANCHES = {
  text: __('targets all protected branches'),
  value: TARGET_PROTECTED,
};

export const TARGET_DEFAULT = 'target_default';

export const PROJECT_TARGET_DEFAULT_BRANCH = {
  text: __('targets default branch'),
  value: TARGET_DEFAULT,
};

export const GROUP_TARGET_DEFAULT_BRANCHES = {
  text: __('target all default branches'),
  value: TARGET_DEFAULT,
};

export const TARGET_BRANCHES = [TARGET_DEFAULT, TARGET_PROTECTED];

export const ANY_COMMIT = 'any';
export const ANY_UNSIGNED_COMMIT = 'unsigned';

export const ANY_OPERATOR = 'ANY';

export const GREATER_THAN_OPERATOR = 'greater_than';

export const LESS_THAN_OPERATOR = 'less_than';

export const VULNERABILITIES_ALLOWED_OPERATORS = [
  { value: ANY_OPERATOR, text: s__('ApprovalRule|any') },
  { value: GREATER_THAN_OPERATOR, text: s__('ApprovalRule|more than') },
];

export const VULNERABILITY_AGE_OPERATORS = [
  { value: ANY_OPERATOR, text: s__('ApprovalRule|any') },
  { value: GREATER_THAN_OPERATOR, text: s__('ApprovalRule|greater than') },
  { value: LESS_THAN_OPERATOR, text: s__('ApprovalRule|less than') },
];

export const SCAN_RESULT_BRANCH_TYPE_OPTIONS = (nameSpaceType = NAMESPACE_TYPES.GROUP) => [
  isGroup(nameSpaceType) ? GROUP_DEFAULT_BRANCHES : PROJECT_DEFAULT_BRANCH,
  ALL_PROTECTED_BRANCHES,
  SPECIFIC_BRANCHES,
];

export const SCAN_EXECUTION_BRANCH_TYPE_OPTIONS = ({
  namespaceType = NAMESPACE_TYPES.GROUP,
  includeTargetTypes = false,
}) => {
  const isGroupNamespace = isGroup(namespaceType);

  // Base options always included
  const baseOptions = [
    ALL_BRANCHES,
    isGroupNamespace ? GROUP_DEFAULT_BRANCHES : PROJECT_DEFAULT_BRANCH,
    ALL_PROTECTED_BRANCHES,
    SPECIFIC_BRANCHES,
  ];

  // Additional options when it is a pipeline scan
  if (includeTargetTypes) {
    const additionalOptions = [
      TARGET_PROTECTED_BRANCHES,
      isGroupNamespace ? GROUP_TARGET_DEFAULT_BRANCHES : PROJECT_TARGET_DEFAULT_BRANCH,
    ];

    return [...baseOptions, ...additionalOptions];
  }

  return baseOptions;
};

export const VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS = [
  ALL_BRANCHES.value,
  ALL_PROTECTED_BRANCHES.value,
  GROUP_DEFAULT_BRANCHES.value,
  TARGET_DEFAULT,
  TARGET_PROTECTED,
];

export const VALID_SCAN_RESULT_BRANCH_TYPE_OPTIONS = [
  ALL_PROTECTED_BRANCHES.value,
  GROUP_DEFAULT_BRANCHES.value,
];

export const BRANCHES_KEY = 'branches';
export const BRANCH_TYPE_KEY = 'branch_type';
export const BRANCH_EXCEPTIONS_KEY = 'branch_exceptions';

export const HUMANIZED_BRANCH_TYPE_TEXT_DICT = {
  [ALL_BRANCHES.value]: s__('SecurityOrchestration|any branch'),
  [ALL_PROTECTED_BRANCHES.value]: s__('SecurityOrchestration|any protected branch'),
  [GROUP_DEFAULT_BRANCHES.value]: s__('SecurityOrchestration|any default branch'),
  [PROJECT_DEFAULT_BRANCH.value]: s__('SecurityOrchestration|the default branch'),
  [TARGET_PROTECTED_BRANCHES.value]: s__(
    'SecurityOrchestration|any branch that targets a protected branch',
  ),
  [GROUP_TARGET_DEFAULT_BRANCHES.value]: s__(
    'SecurityOrchestration|any branch that targets the default branch',
  ),
};

export const MORE_LABEL = s__('SecurityOrchestration|+%{numberOfAdditionalLabels} more');

export const MULTIPLE_SELECTED_LABEL = s__(
  'PolicyRuleMultiSelect|%{firstLabel}, %{secondLabel} %{moreLabel}',
);
export const MULTIPLE_SELECTED_LABEL_SINGLE_OPTION = s__(
  'PolicyRuleMultiSelect|%{firstLabel} %{moreLabel}',
);

export const SELECTED_ITEMS_LABEL = s__('PolicyRuleMultiSelect|Select %{itemTypeName}');
export const ALL_SELECTED_LABEL = s__('PolicyRuleMultiSelect|All %{itemTypeName}');

export const REGULAR_BRANCH = 'regular';
export const PROTECTED_BRANCH = 'protected';

export const BRANCH_TYPES = {
  [PROTECTED_BRANCH]: s__('SecurityOrchestration|Add protected branches'),
  [REGULAR_BRANCH]: s__('SecurityOrchestration|Add regular branches'),
};

export const BRANCH_TYPES_ITEMS = mapToListboxItems(BRANCH_TYPES);

export const EXCEPTION_KEY = 'exception';
export const NO_EXCEPTION_KEY = 'no_exception';
export const EXCEPTION_TYPE_ITEMS = [
  {
    value: EXCEPTION_KEY,
    text: s__('SecurityOrchestration|exceptions'),
  },
  {
    value: NO_EXCEPTION_KEY,
    text: s__('SecurityOrchestration|no exceptions'),
  },
];

export const SPLIT_VIEW_MAX_WIDTH = 1248;
export const SPLIT_VIEW_MIN_WIDTH = 340;
export const YAML_SECTION_INITIAL_WIDTH = 350;
export const RULE_SECTION_INITIAL_WIDTH = SPLIT_VIEW_MAX_WIDTH - YAML_SECTION_INITIAL_WIDTH;
export const RULE_SECTION_COLLAPSED_WIDTH = 76;
export const SPLIT_VIEW_HALF_WIDTH = SPLIT_VIEW_MAX_WIDTH / 2;
export const RULE_SECTION_MAX_WIDTH = SPLIT_VIEW_MAX_WIDTH - 64;

export const AUTO_DISMISSED_ACTION_STORAGE_KEY = 'auto_dismissed_action';
