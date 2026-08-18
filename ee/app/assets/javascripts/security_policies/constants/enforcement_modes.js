import { s__ } from '~/locale';

export const ENFORCEMENT_MODES = [
  {
    id: 'enforce',
    label: s__('SecurityOrchestration|Enforce'),
    description: s__('SecurityOrchestration|Block violations and take configured actions'),
    icon: 'shield',
  },
  {
    id: 'warn',
    label: s__('SecurityOrchestration|Warn'),
    description: s__('SecurityOrchestration|Show warnings but allow proceeding'),
    icon: 'warning',
  },
  {
    id: 'audit',
    label: s__('SecurityOrchestration|Audit'),
    description: s__('SecurityOrchestration|Log only — no blocking or warnings'),
    icon: 'doc-text',
  },
];
