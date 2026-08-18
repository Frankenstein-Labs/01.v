import { s__ } from '~/locale';

export const STEP_BUILD = 'build';
export const STEP_SCOPE = 'scope';
export const STEP_REVIEW = 'review';

export const STEP_ORDER = [STEP_BUILD, STEP_SCOPE, STEP_REVIEW];

export const STEP_LABELS = {
  [STEP_BUILD]: s__('PolicyStore|Build policy'),
  [STEP_SCOPE]: s__('PolicyStore|Select scope'),
  [STEP_REVIEW]: s__('PolicyStore|Review impact'),
};

export const STATUS_COMPLETE = 'complete';
export const STATUS_CURRENT = 'current';
export const STATUS_UPCOMING = 'upcoming';

export const ARIA_CURRENT_STEP = 'step';

// The `type` a catalog item's `fields` entry declares. GenericConfig renders one
// control per type; FIELD_TYPE_TEXT is its fallback.
export const FIELD_TYPE_TEXT = 'text';
export const FIELD_TYPE_TEXTAREA = 'textarea';
export const FIELD_TYPE_SELECT = 'select';
export const FIELD_TYPE_TOGGLE = 'toggle';
export const FIELD_TYPE_CHECKBOX = 'checkbox';
export const FIELD_TYPE_MULTI_BADGE = 'multi_badge';
export const FIELD_TYPE_SEGMENT = 'segment';
export const FIELD_TYPE_SLA_MATRIX = 'sla_matrix';
export const FIELD_TYPE_CODE = 'code';

export const FIELD_TYPES = [
  FIELD_TYPE_TEXT,
  FIELD_TYPE_TEXTAREA,
  FIELD_TYPE_SELECT,
  FIELD_TYPE_TOGGLE,
  FIELD_TYPE_CHECKBOX,
  FIELD_TYPE_MULTI_BADGE,
  FIELD_TYPE_SEGMENT,
  FIELD_TYPE_SLA_MATRIX,
  FIELD_TYPE_CODE,
];

export const BUILD_TAB_TRIGGERS = 'triggers';
export const BUILD_TAB_RULES = 'rules';
export const BUILD_TAB_ACTIONS = 'actions';

export const SCOPE_ALL = 'all';
export const SCOPE_SPECIFIC = 'specific';

export const ENFORCEMENT_ENFORCE = 'enforce';
export const ENFORCEMENT_WARN = 'warn';
export const ENFORCEMENT_AUDIT = 'audit';

export const ENFORCEMENT_MODES = [
  {
    value: ENFORCEMENT_ENFORCE,
    text: s__('PolicyStore|Enforce'),
    description: s__('PolicyStore|Hard enforcement. Violations are blocked as defined.'),
    icon: 'status-failed',
    variant: 'danger',
  },
  {
    value: ENFORCEMENT_WARN,
    text: s__('PolicyStore|Warn'),
    description: s__(
      'PolicyStore|Advisory mode. Violations are flagged but progress is not blocked.',
    ),
    icon: 'status-alert',
    variant: 'warning',
  },
  {
    value: ENFORCEMENT_AUDIT,
    text: s__('PolicyStore|Audit'),
    description: s__(
      'PolicyStore|Monitoring mode. No actions are taken. Violations are recorded in the audit log.',
    ),
    icon: 'status-neutral',
    variant: 'info',
  },
];
