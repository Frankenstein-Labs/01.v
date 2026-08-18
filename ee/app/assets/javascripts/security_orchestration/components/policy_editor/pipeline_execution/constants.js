import { s__, __ } from '~/locale';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const DEFAULT_PIPELINE_EXECUTION_POLICY = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
`;

export const INJECT_CI_PIPELINE_EXECUTION_POLICY = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_ci
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
`;

export const DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
suffix: on_conflict
content:
  include:
    - project: ''
skip_ci:
  allowed: false
variables_override:
  allowed: false
  exceptions: []
`;

export const HOUR_IN_SECONDS = 3600;
export const DAILY = 'daily';
export const WEEKLY = 'weekly';
export const MONTHLY = 'monthly';
export const DEFAULT_SCHEDULE = {
  // branch_type: 'protected', // Enable with https://gitlab.com/gitlab-org/gitlab/-/issues/535547
  type: DAILY,
  start_time: '00:00',
  time_window: {
    value: HOUR_IN_SECONDS,
    distribution: 'random',
  },
};

export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');

export const SCHEDULE = 'schedule';
export const SCHEDULE_TEXT = s__('SecurityOrchestration|Schedule a new');

export const DEPRECATED_INJECT = 'inject_ci';
export const INJECT = 'inject_policy';
export const OVERRIDE = 'override_project_ci';

export const CUSTOM_STRATEGY_OPTIONS = {
  [INJECT]: s__('ScanExecutionPolicy|Inject'),
  [OVERRIDE]: s__('ScanExecutionPolicy|Override'),
};

export const CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED = {
  ...CUSTOM_STRATEGY_OPTIONS,
  [DEPRECATED_INJECT]: s__('ScanExecutionPolicy|Inject without custom stages'),
};

export const CUSTOM_STRATEGY_OPTIONS_KEYS = [
  ...Object.keys(CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED),
  SCHEDULE,
];
export const CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS = mapToListboxItems(CUSTOM_STRATEGY_OPTIONS);
export const CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED_LISTBOX_ITEMS = mapToListboxItems(
  CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED,
);

export const SUFFIX_ON_CONFLICT = 'on_conflict';
export const SUFFIX_NEVER = 'never';

export const SUFFIX_ITEMS = {
  [SUFFIX_ON_CONFLICT]: s__('SecurityOrchestration|On conflict'),
  [SUFFIX_NEVER]: s__('SecurityOrchestration|Never'),
};

export const SUFFIX_LIST_BOX_ITEMS = Object.keys(SUFFIX_ITEMS).map((key) => ({
  value: key,
  text: SUFFIX_ITEMS[key],
}));

export const PIPELINE_EXECUTION_SCHEDULE_POLICY = 'pipeline_execution_schedule_policy';

export const DEFAULT_VARIABLES_OVERRIDE_STATE = { allowed: false, exceptions: [] };

export const DENY = 'deny';
export const ALLOW = 'allow';

export const ALLOW_DENY_OPTIONS = {
  [ALLOW]: __('Allow'),
  [DENY]: __('Deny'),
};

export const ALLOW_DENY_LISTBOX_ITEMS = mapToListboxItems(ALLOW_DENY_OPTIONS);
