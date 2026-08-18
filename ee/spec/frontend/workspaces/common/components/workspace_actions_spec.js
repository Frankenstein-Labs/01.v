import { mount } from '@vue/test-utils';
import { GlDisclosureDropdownItem } from '@gitlab/ui';
import WorkspaceActions from 'ee/workspaces/common/components/workspace_actions.vue';
import { WORKSPACE_STATES as ACTUAL } from 'ee/workspaces/common/constants';

describe('ee/workspaces/components/common/workspace_actions', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = mount(WorkspaceActions, {
      propsData: {
        ...props,
      },
      stubs: {
        MountingPortal: {
          template: '<div><slot /></div>',
        },
      },
    });
  };

  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findDropdownItemWithText = (text) =>
    findDropdownItems().wrappers.find((x) => x.text() === text);
  const findDropdownItemsAsData = () =>
    findDropdownItems().wrappers.map((button) => ({
      text: button.text(),
    }));

  const createButtonData = (text) => ({
    text,
  });

  const RESTART_BUTTON = createButtonData('Restart');
  const START_BUTTON = createButtonData('Start');
  const STOP_BUTTON = createButtonData('Stop');
  const TERMINATE_BUTTON = createButtonData('Terminate');

  it.each`
    workspaceDisplayState       | buttonsData
    ${ACTUAL.creationRequested} | ${[TERMINATE_BUTTON]}
    ${ACTUAL.starting}          | ${[TERMINATE_BUTTON]}
    ${ACTUAL.running}           | ${[STOP_BUTTON, TERMINATE_BUTTON]}
    ${ACTUAL.stopping}          | ${[TERMINATE_BUTTON]}
    ${ACTUAL.stopped}           | ${[START_BUTTON, TERMINATE_BUTTON]}
    ${ACTUAL.terminated}        | ${[]}
    ${ACTUAL.failed}            | ${[RESTART_BUTTON, TERMINATE_BUTTON]}
    ${ACTUAL.error}             | ${[RESTART_BUTTON, TERMINATE_BUTTON]}
    ${ACTUAL.unknown}           | ${[RESTART_BUTTON, TERMINATE_BUTTON]}
    ${ACTUAL.terminating}       | ${[]}
  `(
    'renders buttons - with workspaceDisplayState=$workspaceDisplayState',
    ({ workspaceDisplayState, buttonsData }) => {
      createWrapper({ workspaceDisplayState });

      expect(findDropdownItemsAsData()).toEqual(buttonsData);
    },
  );

  it.each`
    workspaceDisplayState       | text           | actionDesiredState
    ${ACTUAL.creationRequested} | ${'Terminate'} | ${'Terminated'}
    ${ACTUAL.stopped}           | ${'Start'}     | ${'Running'}
    ${ACTUAL.running}           | ${'Stop'}      | ${'Stopped'}
  `(
    'when clicking "$text", emits "click" with "$actionDesiredState"',
    async ({ workspaceDisplayState, text, actionDesiredState }) => {
      createWrapper({ workspaceDisplayState });

      expect(wrapper.emitted('click')).toBeUndefined();

      await findDropdownItemWithText(text).find('button').trigger('click');

      expect(wrapper.emitted('click')).toEqual([[actionDesiredState]]);
    },
  );
});
