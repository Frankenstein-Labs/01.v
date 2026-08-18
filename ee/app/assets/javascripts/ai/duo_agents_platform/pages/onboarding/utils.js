import {
  PROJECT_STATE_READY,
  PROJECT_STATE_ENVIRONMENT_PROBLEM,
  PROJECT_STATE_NOT_ENABLED,
  AUDIENCE_MAINTAINER,
  AUDIENCE_DEVELOPER,
  SECTION_CUSTOMIZE_AGENTS,
} from './constants';

const CONFIGURED_STATES = [PROJECT_STATE_READY, PROJECT_STATE_ENVIRONMENT_PROBLEM];

const SECTION_VISIBILITY = {
  [SECTION_CUSTOMIZE_AGENTS]: { states: CONFIGURED_STATES, audiences: [AUDIENCE_MAINTAINER] },
};

export const resolveProjectState = ({ dapAvailable, environmentHealthy }) => {
  if (!dapAvailable) return PROJECT_STATE_NOT_ENABLED;
  if (!environmentHealthy) return PROJECT_STATE_ENVIRONMENT_PROBLEM;
  return PROJECT_STATE_READY;
};

export const resolveAudience = (canAdminProject) =>
  canAdminProject ? AUDIENCE_MAINTAINER : AUDIENCE_DEVELOPER;

export const isSectionVisible = (sectionKey, { state, audience }) => {
  const rule = SECTION_VISIBILITY[sectionKey];
  if (!rule) return false;

  return rule.states.includes(state) && rule.audiences.includes(audience);
};
