import { s__, sprintf } from '~/locale';
import { mapToListboxItems } from 'ee/security_orchestration/utils';
import {
  LESS_THAN_OPERATOR,
  GREATER_THAN_OPERATOR,
} from 'ee/security_orchestration/components/policy_editor/constants';

export const SEVERITY = 'severity';
export const STATUS = 'status';
export const TYPE = 'type';
export const ATTRIBUTE = 'attribute';
export const AGE = 'age';
export const ALLOW_DENY = 'allow_deny';
export const OVERRIDES = 'overrides';
export const LICENSE_OVERRIDES = 'license_overrides';
export const DENIED = 'denied';
export const ALLOWED = 'allowed';

export const UNKNOWN_LICENSE = {
  value: 'unknown',
  text: s__('ScanResultPolicy|Unknown'),
};

export const AGE_TOOLTIP_MAXIMUM_REACHED = 'maximumReached';
export const AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY = 'noPreviouslyExistingVulnerability';

const AGE_TOOLTIPS = {
  [AGE_TOOLTIP_MAXIMUM_REACHED]: s__('ScanResultPolicy|Only 1 age criteria is allowed'),
  [AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY]: s__(
    'ScanResultPolicy|Age criteria can only be added for pre-existing vulnerabilities',
  ),
};

export const FILTERS = [
  {
    text: s__('ScanResultPolicy|New status'),
    value: STATUS,
    tooltip: s__('ScanResultPolicy|Maximum of two status criteria allowed'),
  },
  {
    text: s__('ScanResultPolicy|New age'),
    value: AGE,
    tooltip: AGE_TOOLTIPS,
  },
  {
    text: s__('ScanResultPolicy|New attribute'),
    value: ATTRIBUTE,
    tooltip: s__('ScanResultPolicy|Maximum of two attribute criteria allowed'),
  },
];

export const LICENCE_FILTERS = [
  {
    text: s__('ScanResultPolicy|License status'),
    value: STATUS,
    tooltip: s__('ScanResultPolicy|Maximum of one license status criteria allowed'),
  },
  {
    text: s__('ScanResultPolicy|License type'),
    value: TYPE,
    tooltip: s__(
      'ScanResultPolicy|You can specify either a deny/allowlist or license types, not both.',
    ),
  },
  {
    text: s__('ScanResultPolicy|Allowlist or Denylist'),
    value: ALLOW_DENY,
    tooltip: s__(
      'ScanResultPolicy|You can specify either a deny/allowlist or license types, not both.',
    ),
  },
  {
    text: s__('ScanResultPolicy|License overrides'),
    value: OVERRIDES,
    tooltip: s__('ScanResultPolicy|Override detected licenses for specific packages.'),
  },
];

export const MAX_LICENSE_OVERRIDES = 500;
export const MAX_PURL_LENGTH = 1024;

export const OVERRIDE_MODE_PATCH = 'patch';
export const OVERRIDE_MODE_OVERWRITE = 'overwrite';

export const OVERRIDE_MODE_OPTIONS = {
  [OVERRIDE_MODE_PATCH]: s__('ScanResultPolicy|Patch (unknown only)'),
  [OVERRIDE_MODE_OVERWRITE]: s__('ScanResultPolicy|Overwrite (always)'),
};

export const MODE_ITEMS = Object.entries(OVERRIDE_MODE_OPTIONS).map(([value, text]) => ({
  value,
  text,
}));

export const ALLOWED_DENIED_OPTIONS = {
  [ALLOWED]: s__('ScanResultPolicy|Allowed'),
  [DENIED]: s__('ScanResultPolicy|Denied'),
};

export const ALLOWED_DENIED_LISTBOX_ITEMS = mapToListboxItems(ALLOWED_DENIED_OPTIONS);

export const KNOWN_EXPLOITED = 'known_exploited';
export const EPSS_SCORE = 'epss_score';
export const ENRICHMENT_DATA_UNAVAILABLE = 'enrichment_data_unavailable';
export const EXPLOIT_SETTINGS = 'exploit_settings';

export const ENRICHMENT_DATA_ACTIONS = {
  BLOCK: 'block',
  IGNORE: 'ignore',
};

export const ENRICHMENT_DATA_ACTION_OPTIONS = [
  {
    value: ENRICHMENT_DATA_ACTIONS.BLOCK,
    text: s__(
      'ScanResultPolicy|When KEV/EPSS data is unavailable, fall back to severity-based blocking',
    ),
    popoverContent: s__(
      "ScanResultPolicy|If KEV/EPSS data doesn't exist for a vulnerability, the policy will fall back to the severity threshold (High) configured above.",
    ),
  },
  {
    value: ENRICHMENT_DATA_ACTIONS.IGNORE,
    text: s__(
      'ScanResultPolicy|When KEV/EPSS data is unavailable, exclude vulnerability from policy evaluation',
    ),
    popoverContent: s__(
      'ScanResultPolicy|Vulnerabilities without KEV/EPSS data will be ignored and will not trigger policy enforcement.',
    ),
  },
];

export const AGE_DAY = 'day';
export const AGE_WEEK = 'week';
export const AGE_MONTH = 'month';
export const AGE_YEAR = 'year';

export const AGE_INTERVALS = [
  { value: AGE_DAY, text: s__('ApprovalRule|day(s)') },
  { value: 'week', text: s__('ApprovalRule|week(s)') },
  { value: 'month', text: s__('ApprovalRule|month(s)') },
  { value: 'year', text: s__('ApprovalRule||year(s)') },
];

export const VULNERABILITY_AGE_ALLOWED_KEYS = ['value', 'interval', 'operator'];

export const FILTERS_STATUS_INDEX = LICENCE_FILTERS.findIndex(({ value }) => value === STATUS);

export const FIX_AVAILABLE = 'fix_available';
export const FALSE_POSITIVE = 'false_positive';

export const VULNERABILITY_ATTRIBUTES = [
  { value: FIX_AVAILABLE, text: s__('ScanResultPolicy|Fix available') },
  { value: FALSE_POSITIVE, text: s__('ScanResultPolicy|False positive') },
];

export const ADDITIONAL_VULNERABILITY_ATTRIBUTES = [
  { value: KNOWN_EXPLOITED, text: s__('ScanResultPolicy|Known exploited') },
  { value: EPSS_SCORE, text: s__('ScanResultPolicy|Epss score') },
];

export const VULNERABILITY_ATTRIBUTE_OPERATORS = [
  { text: s__('ScanResultPolicy|Is'), value: 'true' },
  { text: s__('ScanResultPolicy|Is not'), value: 'false' },
];

export const NEWLY_DETECTED = 'newly_detected';
export const NEW_NEEDS_TRIAGE = 'new_needs_triage';
export const PREVIOUSLY_EXISTING = 'previously_existing';

export const NEEDS_TRIAGE_PLURAL = s__('ApprovalRule|Need triage');
export const NEEDS_TRIAGE_SINGULAR = s__('ApprovalRule|Needs triage');

export const APPROVAL_VULNERABILITY_STATE_GROUPS = {
  [NEWLY_DETECTED]: s__('ApprovalRule|New'),
  [PREVIOUSLY_EXISTING]: s__('ApprovalRule|Previously existing'),
};

export const APPROVAL_VULNERABILITY_STATES = {
  [NEWLY_DETECTED]: {
    new_needs_triage: NEEDS_TRIAGE_SINGULAR,
    new_dismissed: s__('ApprovalRule|Dismissed'),
  },
  [PREVIOUSLY_EXISTING]: {
    detected: s__('ApprovalRule|Needs triage'),
    confirmed: s__('ApprovalRule|Confirmed'),
    dismissed: s__('ApprovalRule|Dismissed'),
    resolved: s__('ApprovalRule|Resolved'),
  },
};

export const DEFAULT_VULNERABILITY_STATES = Object.keys(
  APPROVAL_VULNERABILITY_STATES[NEWLY_DETECTED],
);

export const APPROVAL_VULNERABILITY_STATES_FLAT = Object.values(
  APPROVAL_VULNERABILITY_STATES,
).reduce((acc, states) => ({ ...acc, ...states }), {});

export const EPSS_OPERATOR_TEXT_MAP = {
  [LESS_THAN_OPERATOR]: s__('ScanResultPolicy|less than'),
  [GREATER_THAN_OPERATOR]: s__('ScanResultPolicy|greater than'),
};

export const EPSS_OPERATOR_ITEMS = Object.entries(EPSS_OPERATOR_TEXT_MAP).map(([key, value]) => ({
  value: key,
  text: value,
}));

export const LOW_RISK = sprintf(s__('ScanResultPolicy|Low Risk (10%%)'));
export const MODERATE_RISK = sprintf(s__('ScanResultPolicy|Moderate Risk (50%%)'));
export const HIGH_RISK = sprintf(s__('ScanResultPolicy|High Risk (80%%)'));
export const CRITICAL_RISK = sprintf(s__('ScanResultPolicy|Critical Risk (100%%)'));
export const CUSTOM_VALUE = s__('ScanResultPolicy|Custom Value');

export const EPSS_OPERATOR_VALUE_MAP = {
  [LOW_RISK]: LOW_RISK,
  [MODERATE_RISK]: MODERATE_RISK,
  [HIGH_RISK]: HIGH_RISK,
  [CRITICAL_RISK]: CRITICAL_RISK,
  [CUSTOM_VALUE]: CUSTOM_VALUE,
};

export const EPSS_OPERATOR_VALUE_ITEMS = Object.entries(EPSS_OPERATOR_VALUE_MAP).map(
  ([key, value]) => ({
    value: key,
    text: value,
  }),
);

export const LICENSE_OVERRIDE_MODAL_FIELDS = [
  { key: 'purl', label: s__('ScanResultPolicy|Package (purl)'), thClass: 'gl-w-5/12' },
  { key: 'license', label: s__('ScanResultPolicy|License'), thClass: 'gl-w-4/12' },
  { key: 'mode', label: s__('ScanResultPolicy|Mode'), thClass: 'gl-w-2/12' },
  { key: 'actions', label: '', thClass: 'gl-w-1/12' },
];

export const LICENSE_OVERRIDE_VIEW_FIELDS = [
  {
    key: 'purl',
    label: s__('SecurityOrchestration|Package (purl)'),
    thAttr: { 'data-testid': 'override-purl-th' },
  },
  {
    key: 'license',
    label: s__('SecurityOrchestration|Override license'),
    thAttr: { 'data-testid': 'override-license-th' },
  },
  {
    key: 'mode',
    label: s__('SecurityOrchestration|Mode'),
    thAttr: { 'data-testid': 'override-mode-th' },
  },
];
