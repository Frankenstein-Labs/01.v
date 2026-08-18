import { GlLink } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import WorkspaceStateIndicator from 'ee/workspaces/common/components/workspace_state_indicator.vue';
import WorkspaceActions from 'ee/workspaces/common/components/workspace_actions.vue';
import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from 'ee/workspaces/dropdown_group/constants';
import WorkspaceDropdownItem from 'ee/workspaces/dropdown_group/components/workspace_dropdown_item.vue';
import { calculateDisplayState } from 'ee/workspaces/common/services/calculate_display_state';
import { WORKSPACE } from '../../mock_data';

describe('workspaces/dropdown_group/components/workspace_dropdown_item.vue', () => {
  let wrapper;
  let trackingSpy;

  const createWrapper = ({
    props = { workspace: WORKSPACE },
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(WorkspaceDropdownItem, {
      propsData: {
        ...props,
      },
    });

    trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
  };
  const findWorkspaceStateIndicator = () => wrapper.findComponent(WorkspaceStateIndicator);
  const findWorkspaceActions = () => wrapper.findComponent(WorkspaceActions);
  const findOpenWorkspaceLink = () => wrapper.findComponent(GlLink);

  describe('default', () => {
    const displayState = calculateDisplayState(WORKSPACE.actualState, WORKSPACE.desiredState);

    beforeEach(() => {
      createWrapper();
    });

    it('displays workspace state indicator', () => {
      expect(findWorkspaceStateIndicator().props().workspaceDisplayState).toBe(displayState);
    });

    it('displays the workspace name', () => {
      expect(wrapper.text()).toContain(WORKSPACE.name);
    });

    it('displays workspace creation date', () => {
      expect(wrapper.findComponent(TimeAgoTooltip).props('time')).toBe(WORKSPACE.createdAt);
    });

    it('displays workspace actions', () => {
      expect(findWorkspaceActions().props().workspaceDisplayState).toEqual(displayState);
    });
  });

  describe('when workspace is running', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          workspace: {
            ...WORKSPACE,
            desiredState: WORKSPACE_DESIRED_STATES.running,
            actualState: WORKSPACE_STATES.running,
          },
        },
        mountFn: mountExtended,
      });
    });

    describe('when the dropdown item emits "action" event', () => {
      beforeEach(() => {
        findOpenWorkspaceLink().vm.$emit('click');
      });

      it('tracks event', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_consolidated_edit', {
          label: 'workspace',
        });
      });
    });

    describe('when workspaces action is clicked', () => {
      it('emits update-workspace event with the desiredState provided by the action', () => {
        expect(wrapper.emitted('update-workspace')).toBe(undefined);

        findWorkspaceActions().vm.$emit('click', WORKSPACE_DESIRED_STATES.running);

        expect(wrapper.emitted('update-workspace')).toEqual([
          [{ desiredState: WORKSPACE_DESIRED_STATES.running }],
        ]);
      });
    });

    it.each`
      component                     | selector
      ${'workspace actions parent'} | ${() => findWorkspaceActions().element.parentElement}
      ${'open workspace link'}      | ${() => findOpenWorkspaceLink().element}
    `('stops propagation of keydown event in $component component', ({ selector }) => {
      const event = new KeyboardEvent('keydown', {
        key: 'A',
        keyCode: 65,
        which: 64,
        bubbles: true,
        cancelable: true,
      });
      const spy = jest.spyOn(event, 'stopPropagation');

      selector().dispatchEvent(event);

      expect(spy).toHaveBeenCalled();
    });
  });
});
