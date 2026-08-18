import { s__ } from '~/locale';

export const DECISION_STATUS_PENDING = 'PENDING';
export const DECISION_STATUS_APPROVAL_REQUESTED = 'APPROVAL_REQUESTED';
export const DECISION_STATUS_APPROVED = 'APPROVED';
export const DECISION_STATUS_REJECTED = 'REJECTED';

// A decision is only "decided" once it has a real outcome. Rejected counts: a recorded no is the
// point of the decision log, not a failure to decide.
export const DECIDED_DECISION_STATUSES = [DECISION_STATUS_APPROVED, DECISION_STATUS_REJECTED];

export const DECISION_STATUS_LABELS = {
  [DECISION_STATUS_PENDING]: s__('WorkItemDecisionLog|Pending'),
  [DECISION_STATUS_APPROVAL_REQUESTED]: s__('WorkItemDecisionLog|Approval requested'),
  [DECISION_STATUS_APPROVED]: s__('WorkItemDecisionLog|Approved'),
  [DECISION_STATUS_REJECTED]: s__('WorkItemDecisionLog|Rejected'),
};

export const DECISION_STATUS_ICONS = {
  [DECISION_STATUS_PENDING]: 'status-neutral',
  [DECISION_STATUS_APPROVAL_REQUESTED]: 'status-waiting',
  [DECISION_STATUS_APPROVED]: 'check-circle-filled',
  [DECISION_STATUS_REJECTED]: 'status-cancelled',
};

export const DECISION_STATUS_VARIANTS = {
  [DECISION_STATUS_PENDING]: 'warning',
  [DECISION_STATUS_APPROVAL_REQUESTED]: 'info',
  [DECISION_STATUS_APPROVED]: 'success',
  [DECISION_STATUS_REJECTED]: 'danger',
};

export const DECISION_CATEGORY_SCOPE = 'SCOPE_DECISION';
export const DECISION_CATEGORY_REQUIREMENT = 'REQUIREMENT_ADDED';
export const DECISION_CATEGORY_QUESTION = 'QUESTION_RESOLVED';
export const DECISION_CATEGORY_AUTO = 'AUTO_GENERATED';

export const DECISION_CATEGORY_LABELS = {
  [DECISION_CATEGORY_SCOPE]: s__('WorkItemDecisionLog|Scope decision'),
  [DECISION_CATEGORY_REQUIREMENT]: s__('WorkItemDecisionLog|Requirement added'),
  [DECISION_CATEGORY_QUESTION]: s__('WorkItemDecisionLog|Question resolved'),
  [DECISION_CATEGORY_AUTO]: s__('WorkItemDecisionLog|Auto-generated'),
};

export const DECISION_CATEGORY_VARIANTS = {
  [DECISION_CATEGORY_SCOPE]: 'neutral',
  [DECISION_CATEGORY_REQUIREMENT]: 'neutral',
  [DECISION_CATEGORY_QUESTION]: 'success',
  [DECISION_CATEGORY_AUTO]: 'info',
};

const HOUR_IN_MS = 60 * 60 * 1000;
const DAY_IN_MS = 24 * HOUR_IN_MS;

/**
 * Placeholder decisions for the `workplan_decision_log` flag.
 *
 * There is no backend behind the widget yet, so this stands in for the query result. Timestamps are
 * relative to now rather than fixed, so the rendered "time ago" text stays plausible however long
 * the flag sits behind development. Delete this along with the stub wiring in
 * `work_item_decision_log.vue` once the real `decisionLog` widget lands.
 *
 * @returns {Array<Object>} One decision per visual state: pending, approved, rejected.
 */
/* eslint-disable @gitlab/require-i18n-strings -- Stand-in record content, not UI copy: it would only churn gitlab.pot for strings that get deleted with the stub. */
export const buildStubbedDecisions = () => [
  {
    id: 'gid://gitlab/WorkItems::Decision/1',
    title: 'Should the decision log be available on epics as well as issues?',
    status: DECISION_STATUS_PENDING,
    category: DECISION_CATEGORY_SCOPE,
    createdAt: new Date(Date.now() - 2 * HOUR_IN_MS).toISOString(),
    decidedAt: null,
    author: { id: 'gid://gitlab/User/1', name: 'Sidney Jones' },
    assignee: { id: 'gid://gitlab/User/2', name: 'Zhang Wei' },
    selectedOption: null,
  },
  {
    id: 'gid://gitlab/WorkItems::Decision/2',
    title: 'Surface the log as a widget rather than a separate tab.',
    status: DECISION_STATUS_APPROVED,
    category: DECISION_CATEGORY_AUTO,
    createdAt: new Date(Date.now() - 2 * DAY_IN_MS).toISOString(),
    decidedAt: new Date(Date.now() - DAY_IN_MS).toISOString(),
    author: { id: 'gid://gitlab/User/3', name: 'GitLab Duo' },
    assignee: null,
    selectedOption: {
      id: 'gid://gitlab/WorkItems::DecisionOption/1',
      text: 'Widget below the description',
    },
  },
  {
    id: 'gid://gitlab/WorkItems::Decision/3',
    title: 'Store decisions as system notes instead of their own records.',
    status: DECISION_STATUS_REJECTED,
    category: DECISION_CATEGORY_QUESTION,
    createdAt: new Date(Date.now() - 4 * DAY_IN_MS).toISOString(),
    decidedAt: new Date(Date.now() - 3 * DAY_IN_MS).toISOString(),
    author: { id: 'gid://gitlab/User/4', name: 'Alex Garcia' },
    assignee: null,
    selectedOption: null,
  },
];
/* eslint-enable @gitlab/require-i18n-strings */
