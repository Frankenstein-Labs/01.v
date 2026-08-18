import { __, s__ } from '~/locale';
import {
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_DAST,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_CONTAINER_SCANNING,
  REPORT_TYPE_DEPENDENCY_SCANNING,
} from '~/vue_shared/security_reports/constants';
import {
  SAST_SHORT_NAME,
  SAST_IAC_SHORT_NAME,
  DAST_SHORT_NAME,
  SECRET_DETECTION_NAME,
  CONTAINER_SCANNING_NAME,
  DEPENDENCY_SCANNING_NAME,
} from '~/security_configuration/constants';

export const DEFAULT_AGENT_NAME = '';
export const AGENT_KEY = 'agents';

export const SCAN_EXECUTION_RULES_PIPELINE_KEY = 'pipeline';
export const SCAN_EXECUTION_RULES_SCHEDULE_KEY = 'schedule';

export const SCAN_EXECUTION_RULES_LABELS = {
  [SCAN_EXECUTION_RULES_PIPELINE_KEY]: s__('ScanExecutionPolicy|Triggers:'),
  [SCAN_EXECUTION_RULES_SCHEDULE_KEY]: s__('ScanExecutionPolicy|Schedules:'),
};

export const ADD_CONDITION_LABEL = s__('ScanExecutionPolicy|Add new condition');
export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');

export const SCAN_EXECUTION_PIPELINE_RULE = 'pipeline';
export const SCAN_EXECUTION_SCHEDULE_RULE = 'schedule';

export const SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY = 'branch';
export const SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY = 'agent';
export const SCAN_EXECUTION_RULE_SCOPE_TYPE = {
  [SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY]: s__('ScanExecutionPolicy|branch'),
  [SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY]: s__('ScanExecutionPolicy|agent'),
};

export const SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY = 'daily';
export const SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY = 'weekly';
export const SCAN_EXECUTION_RULE_PERIOD_TYPE = {
  [SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY]: __('daily'),
  [SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY]: __('weekly'),
};

export const ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY = 'specific_tag';
export const ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY = 'selected_automatically';

export const TAGS_MODE_SELECTED_ITEMS = [
  {
    text: s__('ScanExecutionPolicy|has specific tag'),
    value: ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY,
  },
  {
    text: s__('ScanExecutionPolicy|selected automatically'),
    value: ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY,
  },
];

export const DEFAULT_SCANNER = REPORT_TYPE_SECRET_DETECTION;

// Scanners rule mode can generate CI config for, mirroring the backend
// Security::ScanExecutionPolicy::PIPELINE_SCAN_TYPES. cluster_image_scanning is
// intentionally omitted (agent-only, not a pipeline scan), as are fuzzing and
// other scanners exposed only by approval policies — SEP cannot run them.
export const SCAN_EXECUTION_SCANNERS = {
  [REPORT_TYPE_SAST]: SAST_SHORT_NAME,
  [REPORT_TYPE_SAST_IAC]: SAST_IAC_SHORT_NAME,
  [REPORT_TYPE_DAST]: DAST_SHORT_NAME,
  [REPORT_TYPE_SECRET_DETECTION]: SECRET_DETECTION_NAME,
  [REPORT_TYPE_CONTAINER_SCANNING]: CONTAINER_SCANNING_NAME,
  [REPORT_TYPE_DEPENDENCY_SCANNING]: DEPENDENCY_SCANNING_NAME,
};

export const SCANNER_HUMANIZED_TEMPLATE = s__(
  'ScanExecutionPolicy|Run a %{scan} scan with the following options:',
);

export const SCANNER_HUMANIZED_TEMPLATE_ALT = s__(
  'ScanExecutionPolicy|Run %{scan} with the following options:',
);

export const POLICY_ACTION_BUILDER_TAGS_ERROR_KEY = 'tags';
export const POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY = 'profiles';

export const RUNNER_TAGS_PARSING_ERROR = s__(
  'SecurityOrchestration|Non-existing tags have been detected in the policy yaml. As a result, rule mode has been disabled. To enable rule mode, remove those non-existing tags from the policy yaml.',
);

export const DAST_SCANNERS_PARSING_ERROR = s__(
  'SecurityOrchestration|Non-existing DAST profiles have been detected in the policy yaml. As a result, rule mode has been disabled. To enable rule mode, remove those non-existing profiles from the policy yaml.',
);

export const ERROR_MESSAGE_MAP = {
  [POLICY_ACTION_BUILDER_TAGS_ERROR_KEY]: RUNNER_TAGS_PARSING_ERROR,
  [POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY]: DAST_SCANNERS_PARSING_ERROR,
};

// Use PIPELINE_SOURCE_OPTIONS as part of https://gitlab.com/gitlab-org/gitlab/-/issues/554272
export const TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS = {
  merge_request_event: s__('SecurityOrchestration|Merge request pipeline'),
  push: s__('SecurityOrchestration|Code push'),
};

export const PIPELINE_SOURCE_OPTIONS = {
  api: s__('SecurityOrchestration|API request'),
  chat: s__('SecurityOrchestration|ChatOps command'),
  external: s__('SecurityOrchestration|External event'),
  external_pull_request_event: s__('SecurityOrchestration|External pull request'),
  merge_request_event: s__('SecurityOrchestration|Merge request pipeline'),
  pipeline: s__('SecurityOrchestration|Manual pipeline run'),
  push: s__('SecurityOrchestration|Code push'),
  schedule: s__('SecurityOrchestration|Scheduled pipeline'),
  trigger: s__('SecurityOrchestration|Trigger'),
  web: s__('SecurityOrchestration|Web UI'),
  unknown: s__('SecurityOrchestration|Unknown source'),
};

export const SELECTION_CONFIG_CUSTOM = 'custom';
export const SELECTION_CONFIG_DEFAULT = 'default';

export const DEFAULT_CONDITION_STRATEGY = 'merge-request';

export const PIPELINE_SOURCES_KEY = 'pipeline_sources';
