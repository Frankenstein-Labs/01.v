import { n__, s__ } from '~/locale';
import {
  POLICY_STATUS_ACTIVE,
  POLICY_STATUS_DISABLED,
  POLICY_MODE_ENFORCE,
  POLICY_MODE_WARN,
  POLICY_MODE_AUDIT,
} from '../../constants';

const MODE = {
  [POLICY_MODE_ENFORCE]: { label: s__('PolicyStore|Enforce'), variant: 'danger' },
  [POLICY_MODE_WARN]: { label: s__('PolicyStore|Warn'), variant: 'warning' },
  [POLICY_MODE_AUDIT]: { label: s__('PolicyStore|Audit'), variant: 'neutral' },
};

const STATUS = {
  [POLICY_STATUS_ACTIVE]: { label: s__('PolicyStore|Active'), variant: 'success' },
  [POLICY_STATUS_DISABLED]: { label: s__('PolicyStore|Disabled'), variant: 'neutral' },
};

export const modeLabel = (mode) => MODE[mode]?.label || mode;
export const modeVariant = (mode) => MODE[mode]?.variant || 'neutral';

export const statusLabel = (status) => STATUS[status]?.label || status;
export const statusVariant = (status) => STATUS[status]?.variant || 'neutral';

// An unscoped policy applies everywhere, so a zero count means "all", not "none".
export const scopeLabel = (scope) =>
  scope ? n__('%d project', '%d projects', scope) : s__('PolicyStore|All projects');
