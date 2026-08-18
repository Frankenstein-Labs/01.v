import { s__ } from '~/locale';

const WARNING_BG_CLASS = 'gl-bg-orange-500';
const INFO_BG_CLASS = 'gl-bg-blue-500';
const SUCCESS_BG_CLASS = 'gl-bg-green-500';
const DANGER_BG_CLASS = 'gl-bg-red-500';
const MUTED_BG_CLASS = 'gl-bg-gray-200';
export const NEUTRAL_BG_CLASS = 'gl-bg-gray-400';
export const STATUS_PULSE_CLASS = 'flow-stage-status-pulse';

export const STATUS_ALL = 'ALL';
export const STATUS_AWAITING_APPROVAL = 'AWAITING_APPROVAL';
export const STATUS_DEGRADED = 'DEGRADED';
export const STATUS_DEPLOYING = 'DEPLOYING';
export const STATUS_HEALTHY = 'HEALTHY';

export const DEPLOYMENT_STATUS_FILTERS = [
  { id: STATUS_ALL, text: s__('ContinuousDeployment|All') },
  { id: 'ACTIVE', text: s__('ContinuousDeployment|Active') },
  { id: 'FAILED', text: s__('ContinuousDeployment|Failed') },
  { id: 'SUCCEEDED', text: s__('ContinuousDeployment|Succeeded') },
];

export const RELEASE_STATUS_FILTERS = [
  { id: STATUS_ALL, text: s__('ContinuousDeployment|All') },
  { id: 'DEPLOYING', text: s__('ContinuousDeployment|Deploying') },
  { id: 'SUPERSEDED', text: s__('ContinuousDeployment|Superseded') },
  { id: 'ROLLED_BACK', text: s__('ContinuousDeployment|Rolled back') },
];

export const ENVIRONMENT_FILTERS = {
  ALL: s__('ContinuousDeployment|All types'),
  DEVELOPMENT: s__('ContinuousDeployment|Development'),
  QA: s__('ContinuousDeployment|QA'),
  STAGING: s__('ContinuousDeployment|Staging'),
  PRODUCTION: s__('ContinuousDeployment|Production'),
};

// CdEnvironmentTier values, in promotion order.
export const TIERS = [
  { key: 'DEVELOPMENT', label: s__('ContinuousDeployment|Development') },
  { key: 'QA', label: s__('ContinuousDeployment|QA') },
  { key: 'STAGING', label: s__('ContinuousDeployment|Staging') },
  { key: 'PRODUCTION', label: s__('ContinuousDeployment|Production') },
];

export const statusDescriptionMap = {
  [STATUS_AWAITING_APPROVAL]: s__('ContinuousDeployment|Waiting for your approval'),
  [STATUS_DEGRADED]: s__('ContinuousDeployment|Degradation detected'),
  [STATUS_DEPLOYING]: s__('ContinuousDeployment|Deployment in progress'),
  [STATUS_HEALTHY]: s__('ContinuousDeployment|All systems healthy'),
};

export const statusSortOrderMap = {
  [STATUS_AWAITING_APPROVAL]: 0,
  [STATUS_DEGRADED]: 1,
  [STATUS_DEPLOYING]: 2,
  [STATUS_HEALTHY]: 3,
};

export const statusTextMap = {
  [STATUS_AWAITING_APPROVAL]: s__('ContinuousDeployment|Approval needed'),
  [STATUS_DEGRADED]: s__('ContinuousDeployment|Degraded'),
  [STATUS_DEPLOYING]: s__('ContinuousDeployment|Deploying'),
  [STATUS_HEALTHY]: s__('ContinuousDeployment|Healthy'),
};

export const statusVariantMap = {
  [STATUS_AWAITING_APPROVAL]: 'warning',
  [STATUS_DEGRADED]: 'warning',
  [STATUS_DEPLOYING]: 'info',
  [STATUS_HEALTHY]: 'success',
};

// Constraints
export const MAX_NAME_LENGTH = 255;
export const MAX_DESCRIPTION_LENGTH = 255;

export const PAGE_SIZE_SM = 5;
export const PAGE_SIZE_MD = 10;
export const PAGE_SIZE_LG = 20;
export const PAGE_SIZE_OPTIONS = [PAGE_SIZE_SM, PAGE_SIZE_MD, PAGE_SIZE_LG];

export const ENVIRONMENTS_PAGE_SIZE = 50;

export const ENVIRONMENT_DRIVER_REF = 'argo-rollouts';

export const ARTIFACT_SOURCE_TYPE = 'oci_image';

export const LINK_TYPES = [
  { value: 'RUNBOOK', icon: 'book', label: s__('ContinuousDeployment|Runbook') },
  { value: 'DASHBOARD', icon: 'chart', label: s__('ContinuousDeployment|Dashboard') },
  { value: 'DOCS', icon: 'documents', label: s__('ContinuousDeployment|Docs') },
  { value: 'REPOSITORY', icon: 'code', label: s__('ContinuousDeployment|Repository') },
  { value: 'CHAT', icon: 'comments', label: s__('ContinuousDeployment|Chat / Slack') },
  { value: 'ISSUE_TRACKER', icon: 'issues', label: s__('ContinuousDeployment|Issue tracker') },
  { value: 'ON_CALL', icon: 'notifications', label: s__('ContinuousDeployment|On-call rotation') },
  {
    value: 'CHANGE_REQUEST',
    icon: 'merge-request',
    label: s__('ContinuousDeployment|Change / CR system'),
  },
  { value: 'OTHER', icon: 'link', label: s__('ContinuousDeployment|Other') },
];

export const DEFAULT_LINK_TYPE = 'RUNBOOK';

export const linkTypeIcon = (value) =>
  LINK_TYPES.find((type) => type.value === value)?.icon ?? 'link';

export const APPLICATION_FILTERS = [
  {
    id: 'ALL',
    text: s__('ContinuousDeployment|All'),
  },
  {
    id: 'RUNNING',
    text: s__('ContinuousDeployment|Running'),
  },
  {
    id: 'DEGRADED',
    text: s__('ContinuousDeployment|Degraded'),
  },
];

export const SERVICE_HEALTH_VARIANTS = {
  HEALTHY: 'success',
  DEGRADED: 'warning',
  FAILED: 'danger',
  UNKNOWN: 'neutral',
};

export const UNKNOWN_LABEL = s__('ContinuousDeployment|Unknown');

export const SERVICE_HEALTH_LABELS = {
  HEALTHY: s__('ContinuousDeployment|Healthy'),
  DEGRADED: s__('ContinuousDeployment|Degraded'),
  FAILED: s__('ContinuousDeployment|Failed'),
  UNKNOWN: UNKNOWN_LABEL,
};

export const SERVICE_HEALTH_SEVERITY_ORDER = ['FAILED', 'DEGRADED', 'HEALTHY', 'UNKNOWN'];

export const SERVICE_HEALTH_DOT_CLASSES = {
  HEALTHY: SUCCESS_BG_CLASS,
  DEGRADED: WARNING_BG_CLASS,
  FAILED: DANGER_BG_CLASS,
  UNKNOWN: NEUTRAL_BG_CLASS,
};

export const EMPTY_PLACEHOLDER = '—';

export const ROLLOUT_STATE_VARIANTS = {
  PENDING: 'warning',
  IN_PROGRESS: 'info',
  PAUSED: 'neutral',
  COMPLETED: 'success',
  FAILED: 'danger',
  CANCELLED: 'neutral',
};

export const ROLLOUT_STATE_LABELS = {
  PENDING: s__('ContinuousDeployment|Pending'),
  IN_PROGRESS: s__('ContinuousDeployment|In progress'),
  PAUSED: s__('ContinuousDeployment|Paused'),
  COMPLETED: s__('ContinuousDeployment|Available'),
  FAILED: s__('ContinuousDeployment|Failed'),
  CANCELLED: s__('ContinuousDeployment|Cancelled'),
};

export const ROLLOUT_STATE_DOT_CLASSES = {
  PENDING: WARNING_BG_CLASS,
  IN_PROGRESS: `${INFO_BG_CLASS} ${STATUS_PULSE_CLASS}`,
  PAUSED: NEUTRAL_BG_CLASS,
  COMPLETED: SUCCESS_BG_CLASS,
  FAILED: DANGER_BG_CLASS,
  CANCELLED: NEUTRAL_BG_CLASS,
};

export const TH_CLASS = 'gl-pb-2 !gl-text-sm !gl-text-secondary';
export const TD_CLASS = 'gl-py-2 !gl-text-sm';

export const ROW_CLASS = 'gl-cursor-pointer hover:gl-bg-subtle';
export const ROW_SELECTED_CLASS = 'gl-bg-blue-50 gl-shadow-[inset_2px_0_0_0_var(--blue-500)]';
export const ROW_RECENT_CLASS = 'gl-bg-purple-50';

export const FLOW_ITEM_STEP = 'step';
export const FLOW_ITEM_STAGE = 'stage';

const STEP_CATEGORIES = {
  TRIGGER: 'trigger',
  DEPLOY: 'deploy',
  APPROVE: 'approve',
  WAIT: 'wait',
};

export const STEP_STATES = {
  PENDING: 'PENDING',
  RUNNING: 'RUNNING',
  AWAITING_APPROVAL: 'AWAITING_APPROVAL',
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
  SUCCESS: 'SUCCESS',
  FAILED: 'FAILED',
  SKIPPED: 'SKIPPED',
  CANCELLED: 'CANCELLED',
};

export const STEP_CATEGORY_ICONS = {
  [STEP_CATEGORIES.TRIGGER]: 'rocket',
  [STEP_CATEGORIES.DEPLOY]: 'environment',
  [STEP_CATEGORIES.APPROVE]: 'approval',
  [STEP_CATEGORIES.WAIT]: 'hourglass',
};

export const STEP_UNKNOWN_ICON = 'status_notfound';

export const ROLLOUT_STAGE_STEP_TYPE = 'com.gitlab.cd.steps.stage';

export const STEP_ACTION_CATEGORIES = {
  deploy: STEP_CATEGORIES.DEPLOY,
  promote: STEP_CATEGORIES.DEPLOY,
  approval: STEP_CATEGORIES.APPROVE,
  wait: STEP_CATEGORIES.WAIT,
};

export const STAGE_FALLBACK_TITLE = s__('FlowEditor|Stage');

export const FLOW_TRIGGER = {
  kind: FLOW_ITEM_STEP,
  category: STEP_CATEGORIES.TRIGGER,
  state: STEP_STATES.SUCCESS,
  title: s__('FlowEditor|Trigger'),
};

const PENDING_STEP_CLASSES = 'gl-border-default gl-bg-subtle gl-text-disabled';
const RUNNING_STEP_CLASSES = 'gl-border-feedback-info gl-bg-feedback-info gl-text-status-info';
const AWAITING_STEP_CLASSES =
  'gl-border-feedback-warning gl-bg-status-warning gl-text-status-warning';
const SUCCESS_STEP_CLASSES = 'gl-border-feedback-success gl-bg-default gl-text-status-success';
const DANGER_STEP_CLASSES = 'gl-border-feedback-danger gl-bg-default gl-text-status-danger';
const SETTLED_STEP_CLASSES = 'gl-border-subtle gl-bg-subtle gl-text-disabled';

export const UNKNOWN_STEP_CLASSES =
  'gl-border-dashed gl-border-default gl-bg-subtle gl-text-subtle';

export const STEP_STATE_CLASSES = {
  [STEP_STATES.PENDING]: PENDING_STEP_CLASSES,
  [STEP_STATES.RUNNING]: RUNNING_STEP_CLASSES,
  [STEP_STATES.AWAITING_APPROVAL]: AWAITING_STEP_CLASSES,
  [STEP_STATES.APPROVED]: SUCCESS_STEP_CLASSES,
  [STEP_STATES.REJECTED]: DANGER_STEP_CLASSES,
  [STEP_STATES.SUCCESS]: SUCCESS_STEP_CLASSES,
  [STEP_STATES.FAILED]: DANGER_STEP_CLASSES,
  [STEP_STATES.SKIPPED]: SETTLED_STEP_CLASSES,
  [STEP_STATES.CANCELLED]: SETTLED_STEP_CLASSES,
};

export const STEP_STATE_LABELS = {
  [STEP_STATES.PENDING]: s__('ContinuousDeployment|Pending'),
  [STEP_STATES.RUNNING]: s__('ContinuousDeployment|Running'),
  [STEP_STATES.AWAITING_APPROVAL]: s__('ContinuousDeployment|Awaiting approval'),
  [STEP_STATES.APPROVED]: s__('ContinuousDeployment|Approved'),
  [STEP_STATES.REJECTED]: s__('ContinuousDeployment|Rejected'),
  [STEP_STATES.SUCCESS]: s__('ContinuousDeployment|Succeeded'),
  [STEP_STATES.FAILED]: s__('ContinuousDeployment|Failed'),
  [STEP_STATES.SKIPPED]: s__('ContinuousDeployment|Skipped'),
  [STEP_STATES.CANCELLED]: s__('ContinuousDeployment|Cancelled'),
};

export const STEP_STATE_DOT_CLASSES = {
  [STEP_STATES.PENDING]: NEUTRAL_BG_CLASS,
  [STEP_STATES.RUNNING]: INFO_BG_CLASS,
  [STEP_STATES.AWAITING_APPROVAL]: WARNING_BG_CLASS,
  [STEP_STATES.APPROVED]: SUCCESS_BG_CLASS,
  [STEP_STATES.REJECTED]: DANGER_BG_CLASS,
  [STEP_STATES.SUCCESS]: SUCCESS_BG_CLASS,
  [STEP_STATES.FAILED]: DANGER_BG_CLASS,
  [STEP_STATES.SKIPPED]: MUTED_BG_CLASS,
  [STEP_STATES.CANCELLED]: MUTED_BG_CLASS,
};

export const STEP_MUTED_STATES = [STEP_STATES.PENDING, STEP_STATES.SKIPPED, STEP_STATES.CANCELLED];

export const STEP_FINISHED_STATES = [
  STEP_STATES.APPROVED,
  STEP_STATES.REJECTED,
  STEP_STATES.SUCCESS,
  STEP_STATES.FAILED,
  STEP_STATES.SKIPPED,
  STEP_STATES.CANCELLED,
];

export const STAGE_RUNNING_STATE = STEP_STATES.RUNNING;
