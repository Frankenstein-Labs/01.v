import { pick } from 'lodash-es';
import { s__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
export const WORKSPACE_STATES = {
  creationRequested: 'CreationRequested',
  starting: 'Starting',
  running: 'Running',
  stopping: 'Stopping',
  stopped: 'Stopped',
  terminating: 'Terminating',
  terminated: 'Terminated',
  failed: 'Failed',
  error: 'Error',
  unknown: 'Unknown',
};

export const WORKSPACE_DESIRED_STATES = {
  ...pick(WORKSPACE_STATES, 'running', 'stopped', 'terminated'),
  restartRequested: 'RestartRequested',
};
/* eslint-enable @gitlab/require-i18n-strings */

export const WORKSPACES_DROPDOWN_GROUP_PAGE_SIZE = 20;

export const I18N_LOADING_WORKSPACES_FAILED = s__(
  'Workspaces|Unable to load current workspaces. Please try again or contact an administrator.',
);

export const WORKSPACES_LIST_PAGE_SIZE = 10;
export const WORKSPACES_LIST_POLL_INTERVAL = 3000;
export const GET_WORKSPACE_STATE_INTERVAL = 1000;

export const CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME = 'click_new_workspace_button';
export const CLICK_OPEN_WORKSPACE_BUTTON_EVENT_NAME = 'click_open_workspace_button';
