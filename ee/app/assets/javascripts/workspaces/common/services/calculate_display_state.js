import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from '../constants';

/**
 * Calculates a Workspace's displayState based on the Workspace's actualState and
 * desiredState. A "displayState" is a UI-specific state used by several components
 * in the User's Workspaces application to determine how to communicate a Workspace's state
 * and which actions are available in the UI.
 *
 * IMPLEMENTATION NOTE: The order of the rules implemented in this function matters.
 *
 * @param {String} workspaceActualState
 * @param {String} workspaceDesiredState
 * @returns {string}
 */
export const calculateDisplayState = (workspaceActualState, workspaceDesiredState) => {
  /**
   * 1st rule: The workspace is terminated. The workspace can't transition to other states
   * from this actual state therefore is final.
   */
  if (workspaceActualState === WORKSPACE_STATES.terminated) {
    return WORKSPACE_STATES.terminated;
  }

  /**
   * 2nd rule: The user wants to terminate the workspace. The user can't cancel the operation
   * and the workspace can't transition to other states after being terminated per the 1st rule.
   */
  if (workspaceDesiredState === WORKSPACE_DESIRED_STATES.terminated) {
    return WORKSPACE_STATES.terminating;
  }

  /**
   * 3rd rule: Actual state takes precedence over desired state when:
   * - The workspace's actual state and the workspaces's desired state are the same.
   * - The workspace's actual state is unknown, failed, error, or terminating.
   * */
  if (
    workspaceActualState === workspaceDesiredState ||
    [
      WORKSPACE_STATES.unknown,
      WORKSPACE_STATES.failed,
      WORKSPACE_STATES.error,
      WORKSPACE_STATES.terminating,
    ].includes(workspaceActualState)
  ) {
    return workspaceActualState;
  }

  /*
   * 4th rule: If the workspace's desired state is Stopped, we display that the Workspace is stopping.
   */
  if ([WORKSPACE_DESIRED_STATES.stopped].includes(workspaceDesiredState)) {
    return WORKSPACE_STATES.stopping;
  }

  /**
   * 5th rule: If the workspace's desired state is RestartRequested, we display that the Workspace is stopping
   * unless the workspace is already stopped. The backend stops a workspace when the desired state is RestartRequested
   * and, after the workspace is stopped, the backend will set desiredState to running
   * https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/workspaces/#possible-desired_state-values
   */
  if (workspaceDesiredState === WORKSPACE_DESIRED_STATES.restartRequested) {
    return workspaceActualState === WORKSPACE_STATES.stopped
      ? WORKSPACE_STATES.starting
      : WORKSPACE_STATES.stopping;
  }

  /**
   * 6th rule: If the workspace's desired state is Running, display that the workspace is starting
   * unless the workspace actual space is CreationRequested because we want to display a "Creating" label.
   */
  if (
    workspaceDesiredState === WORKSPACE_DESIRED_STATES.running &&
    workspaceActualState !== WORKSPACE_STATES.creationRequested
  ) {
    return WORKSPACE_STATES.starting;
  }

  /**
   * If the rules above are not satisfied, it's safe to return the actual state.
   */
  return workspaceActualState;
};
