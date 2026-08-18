import { s__ } from '~/locale';
import {
  FIELD_TYPE_CODE,
  FIELD_TYPE_SELECT,
  FIELD_TYPE_TEXT,
} from '../components/editor/constants';
import { CATEGORY_ADVANCED, CATEGORY_DEPLOYMENT } from './categories';
import { idAsOption } from './helpers';
import { DEPLOYMENT_GATE_REGO } from './rego_templates';

// Rules a policy can evaluate. `id` is persisted as the rule object's `type`, so it is the wire
// value, and the ids mirror the backend's catalog (Gitlab::PolicyStore::Rules in the
// gitlab-policy-store gem) exactly — the API supplies which rules exist, this file supplies
// their presentation. `RULE_CUSTOM` in particular is fixed:
// EE::Ci::ProcessBuildService#rego_of looks for `rule['type'] == 'custom'` when reading a
// policy's Rego back at evaluation time.
export const RULE_CUSTOM = 'custom';
export const RULE_CALENDAR = 'calendar';
export const RULE_ENVIRONMENT = 'environment';

export const RULES = [
  {
    id: RULE_CUSTOM,
    category: CATEGORY_ADVANCED,
    label: s__('PolicyStore|Custom Rule (Rego)'),
    description: s__('PolicyStore|Evaluate the event against custom OPA/Rego policy code'),
    icon: 'code',
    fields: [
      {
        key: 'policy',
        type: FIELD_TYPE_CODE,
        label: s__('PolicyStore|Rego policy definition'),
        helpText: s__(
          'PolicyStore|OPA/Rego policy evaluated server-side when the event is received. Maximum 32 KB.',
        ),
        maxLength: 32768,
        default: DEPLOYMENT_GATE_REGO,
      },
    ],
  },
  {
    id: RULE_CALENDAR,
    category: CATEGORY_DEPLOYMENT,
    label: s__('PolicyStore|Freeze Window'),
    description: s__('PolicyStore|Block deployments during configured freeze periods'),
    icon: 'clock',
    fields: [
      {
        key: 'windowStart',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Window start'),
        placeholder: s__('PolicyStore|e.g. 2026-12-20T00:00:00Z'),
      },
      {
        key: 'windowEnd',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Window end'),
        placeholder: s__('PolicyStore|e.g. 2027-01-02T00:00:00Z'),
      },
      {
        key: 'recurring',
        type: FIELD_TYPE_SELECT,
        label: s__('PolicyStore|Recurring'),
        options: [
          idAsOption('daily'),
          idAsOption('weekly'),
          idAsOption('monthly'),
          idAsOption('yearly'),
        ],
      },
      {
        key: 'timezone',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Timezone'),
        placeholder: s__('PolicyStore|e.g. America/New_York'),
      },
    ],
  },
  {
    id: RULE_ENVIRONMENT,
    category: CATEGORY_DEPLOYMENT,
    label: s__('PolicyStore|Environment State'),
    description: s__(
      'PolicyStore|When a deployment environment is not in the required operational state',
    ),
    icon: 'deployments',
    fields: [
      {
        key: 'environment',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Environment'),
        placeholder: s__('PolicyStore|e.g. production, prod-*'),
        required: true,
        helpText: s__('PolicyStore|Environment name or pattern this rule applies to.'),
      },
    ],
  },
];
