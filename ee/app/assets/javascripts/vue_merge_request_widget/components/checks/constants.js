import { s__, __ } from '~/locale';

export const SECURITY_POLICY_PIPELINE_CHECK = 'SECURITY_POLICY_PIPELINE_CHECK';
export const BLOCKING_STATUSES = ['FAILED', 'WARNING'];

export const WARN_MODE = 'warn_mode';
export const EXCEPTION_MODE = 'exception_mode';

export const WARN_MODE_BYPASS_REASONS = [
  {
    value: 'POLICY_FALSE_POSITIVE',
    text: s__('SecurityOrchestration|Policy false positive'),
  },
  {
    value: 'SCANNER_FALSE_POSITIVE',
    text: s__('SecurityOrchestration|Scanner false positive'),
  },
  { value: 'EMERGENCY_HOT_FIX', text: s__('SecurityOrchestration|Emergency hotfix') },
  { value: 'OTHER', text: s__('SecurityOrchestration|Other') },
];

export const POLICY_EXCEPTIONS_BYPASS_REASONS = [
  { text: s__('SecurityOrchestration|Emergency production issue'), value: 'emergency' },
  { text: s__('SecurityOrchestration|Critical business deadline'), value: 'critical' },
  { text: s__('SecurityOrchestration|Technical limitation'), value: 'technical' },
  {
    text: s__('SecurityOrchestration|Authorized business risk acceptance'),
    value: 'authorized_risk',
  },
  { text: __('Other'), value: 'other' },
];

export const WARN_MODE_NEXT_STEPS = [
  s__('SecurityOrchestration|All selected policy requirements will be bypassed.'),
  s__('SecurityOrchestration|The action will be logged in the audit log.'),
  s__(
    'SecurityOrchestration|The security findings remain in their current status and are still visible, but will no longer block the merge request.',
  ),
];

export const INITIAL_STATE_NEXT_STEPS = [
  s__(
    'SecurityOrchestration|You have permissions to bypass all checks in this merge request or selectively only bypass Warn Mode policies.',
  ),
  s__(
    'SecurityOrchestration|Choose from the options below based on how you would like to proceed.',
  ),
];

export const POLICY_EXCEPTIONS_NEXT_STEPS = [
  s__(
    'SecurityOrchestration|All policy requirements will be bypassed for this MR and can be merged immediately',
  ),
  s__(
    'SecurityOrchestration|A formal exception record will be created and linked to this merge request',
  ),
  s__('SecurityOrchestration|The action will be logged in the audit log with your justification'),
  s__('SecurityOrchestration|Security teams will be notified of this exception'),
  s__(
    'SecurityOrchestration|The security findings remain in their current status and are still visible, but will no longer block the merge request.',
  ),
];
