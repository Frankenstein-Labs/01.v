import { calculateDisplayState } from 'ee/workspaces/common/services/calculate_display_state';
import { WORKSPACE_STATES, WORKSPACE_DESIRED_STATES } from 'ee/workspaces/common/constants';

describe('workspaces/services/calculate_display_state', () => {
  /**
   * This test exercises all the possible combinations of actualState and desiredState even if not
   * all combinations are possible. For example, the user can't try to start a workspace that errored.
   */
  it.each`
    workspaceActualState                  | workspaceDesiredState                        | result
    ${WORKSPACE_STATES.creationRequested} | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.creationRequested}
    ${WORKSPACE_STATES.creationRequested} | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.creationRequested} | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.creationRequested} | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.starting}          | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.starting}
    ${WORKSPACE_STATES.starting}          | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.starting}          | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.starting}          | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.running}           | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.running}
    ${WORKSPACE_STATES.running}           | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.running}           | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.running}           | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.stopping}          | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.starting}
    ${WORKSPACE_STATES.stopping}          | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.stopping}          | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.stopping}          | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.stopping}
    ${WORKSPACE_STATES.stopped}           | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.starting}
    ${WORKSPACE_STATES.stopped}           | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.stopped}
    ${WORKSPACE_STATES.stopped}           | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.stopped}           | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.starting}
    ${WORKSPACE_STATES.terminating}       | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.terminating}       | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.terminating}       | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.terminating}       | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.terminated}        | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.terminated}
    ${WORKSPACE_STATES.terminated}        | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.terminated}
    ${WORKSPACE_STATES.terminated}        | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminated}
    ${WORKSPACE_STATES.terminated}        | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.terminated}
    ${WORKSPACE_STATES.failed}            | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.failed}
    ${WORKSPACE_STATES.failed}            | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.failed}
    ${WORKSPACE_STATES.failed}            | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.failed}            | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.failed}
    ${WORKSPACE_STATES.error}             | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.error}
    ${WORKSPACE_STATES.error}             | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.error}
    ${WORKSPACE_STATES.error}             | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.error}             | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.error}
    ${WORKSPACE_STATES.unknown}           | ${WORKSPACE_DESIRED_STATES.running}          | ${WORKSPACE_STATES.unknown}
    ${WORKSPACE_STATES.unknown}           | ${WORKSPACE_DESIRED_STATES.stopped}          | ${WORKSPACE_STATES.unknown}
    ${WORKSPACE_STATES.unknown}           | ${WORKSPACE_DESIRED_STATES.terminated}       | ${WORKSPACE_STATES.terminating}
    ${WORKSPACE_STATES.unknown}           | ${WORKSPACE_DESIRED_STATES.restartRequested} | ${WORKSPACE_STATES.unknown}
  `(
    'label=$label, icon=$iconName, variant=$variant when actualState=$workspaceActualState and desiredState=$workspaceDesiredState',
    ({ workspaceActualState, workspaceDesiredState, result }) => {
      expect(calculateDisplayState(workspaceActualState, workspaceDesiredState)).toBe(result);
    },
  );
});
