import { s__ } from '~/locale';

export const SESSION_AWAITING_INPUT_GROUP = {
  statuses: ['INPUT_REQUIRED', 'PLAN_APPROVAL_REQUIRED', 'TOOL_CALL_APPROVAL_REQUIRED'],
  title: s__('DuoAgentPlatform|Awaiting your input'),
};

export const SESSION_OTHER_GROUPS = [
  { statuses: ['RUNNING'], title: s__('DuoAgentPlatform|Running') },
  { statuses: ['PAUSED'], title: s__('DuoAgentPlatform|Paused') },
  { statuses: ['FAILED'], title: s__('DuoAgentPlatform|Failed') },
  { statuses: ['CREATED'], title: s__('DuoAgentPlatform|Created') },
  { statuses: ['FINISHED'], title: s__('DuoAgentPlatform|Completed') },
  { statuses: ['STOPPED'], title: s__('DuoAgentPlatform|Cancelled') },
];

export const AWAITING_INPUT_HEADER_BG_CLASS = 'gl-bg-feedback-warning';
export const OTHER_GROUP_HEADER_BG_CLASS = 'gl-bg-subtle';
