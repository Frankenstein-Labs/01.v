import { getAgentStatusIcon } from 'ee/ai/duo_agents_platform/utils';

const COLOR_TO_DOT_CLASS = {
  green: 'gl-bg-status-success',
  red: 'gl-bg-status-danger',
  blue: 'gl-bg-status-info',
  orange: 'gl-bg-status-warning',
  neutral: 'gl-bg-status-neutral',
};

export const getStatusDotClass = (status) => {
  const { color } = getAgentStatusIcon(status);
  return COLOR_TO_DOT_CLASS[color] ?? COLOR_TO_DOT_CLASS.neutral;
};
