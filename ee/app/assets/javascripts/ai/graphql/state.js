import { makeVar } from '@apollo/client/core';

/**
 * Note: For Vue 3 migration compatibility these variables should be declared on their own module.
 *
 * This file should not import Vue, VueApollo, or other dependencies that may cause a duplication
 * as these variables share state between Vue 2 and Vue 3 applications.
 */
export const isMaximizedVar = makeVar(false);
export const infoToggleStatesVar = makeVar({});
export const agentSessionStatusVar = makeVar(null);
export const panelTitleVar = makeVar(null);
export const panelSubtitleVar = makeVar(null);
