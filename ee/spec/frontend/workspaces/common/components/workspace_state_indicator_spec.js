import { shallowMount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import WorkspaceStateIndicator from 'ee/workspaces/common/components/workspace_state_indicator.vue';
import { WORKSPACE_STATES } from 'ee/workspaces/common/constants';

describe('WorkspaceStateIndicator', () => {
  let wrapper;

  const createWrapper = ({ workspaceDisplayState }) => {
    wrapper = shallowMount(WorkspaceStateIndicator, {
      propsData: {
        workspaceDisplayState,
      },
    });
  };

  it.each`
    workspaceDisplayState                 | iconName    | label              | variant
    ${WORKSPACE_STATES.creationRequested} | ${'status'} | ${'Creating'}      | ${'success'}
    ${WORKSPACE_STATES.starting}          | ${'status'} | ${'Starting'}      | ${'success'}
    ${WORKSPACE_STATES.running}           | ${''}       | ${'Running'}       | ${'success'}
    ${WORKSPACE_STATES.stopping}          | ${'status'} | ${'Stopping'}      | ${'info'}
    ${WORKSPACE_STATES.stopped}           | ${''}       | ${'Stopped'}       | ${'info'}
    ${WORKSPACE_STATES.terminating}       | ${'status'} | ${'Terminating'}   | ${'neutral'}
    ${WORKSPACE_STATES.terminated}        | ${''}       | ${'Terminated'}    | ${'neutral'}
    ${WORKSPACE_STATES.failed}            | ${''}       | ${'Failed'}        | ${'danger'}
    ${WORKSPACE_STATES.error}             | ${''}       | ${'Error'}         | ${'danger'}
    ${WORKSPACE_STATES.unknown}           | ${''}       | ${'Unknown state'} | ${'danger'}
  `(
    'label=$label, icon=$iconName, variant=$variant when displayState=$workspaceDisplayState',
    ({ workspaceDisplayState, iconName, label, variant }) => {
      createWrapper({ workspaceDisplayState });

      const badge = wrapper.findComponent(GlBadge);

      expect(badge.props()).toMatchObject({
        icon: iconName,
        iconSize: 'sm',
        iconOpticallyAligned: false,
        variant,
      });
      expect(badge.text()).toBe(label);
    },
  );
});
