import { s__ } from '~/locale';

export const ENFORCE_VALUE = 'enforce';

export const WARN_VALUE = 'warn';

export const ENFORCEMENT_OPTIONS = [
  {
    value: ENFORCE_VALUE,
    text: s__('SecurityOrchestration|Enforce'),
    description: s__('SecurityOrchestration|Hard enforcement. Violations are blocked as defined.'),
    icon: 'status-failed',
    iconClass: 'gl-text-danger',
  },
  {
    value: WARN_VALUE,
    text: s__('SecurityOrchestration|Warn'),
    description: s__(
      'SecurityOrchestration|Advisory mode. Violations are flagged but progress is not blocked.',
    ),
    icon: 'status-alert',
    iconClass: 'gl-text-warning',
  },
];
