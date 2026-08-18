import { shallowMount } from '@vue/test-utils';
import SidebarDropdownWidget from 'ee/sidebar/components/sidebar_dropdown_widget.vue';
import SidebarDropdownWidgetCE from '~/sidebar/components/sidebar_dropdown_widget.vue';
import { IssuableAttributeType } from 'ee/sidebar/constants';
import { TYPE_ISSUE } from '~/issues/constants';
import { mockIssue } from '../mock_data';

describe('EE SidebarDropdownWidget', () => {
  let wrapper;

  const findCEWidget = () => wrapper.findComponent(SidebarDropdownWidgetCE);

  const createComponent = () => {
    wrapper = shallowMount(SidebarDropdownWidget, {
      propsData: {
        workspacePath: mockIssue.projectPath,
        attrWorkspacePath: mockIssue.groupPath,
        iid: mockIssue.iid,
        issuableType: TYPE_ISSUE,
        issuableAttribute: IssuableAttributeType.Iteration,
      },
    });
  };

  it('renders the CE sidebar dropdown widget', () => {
    createComponent();

    expect(findCEWidget().exists()).toBe(true);
  });

  it('forwards the relevant props to the CE widget', () => {
    createComponent();

    expect(findCEWidget().props()).toMatchObject({
      workspacePath: mockIssue.projectPath,
      attrWorkspacePath: mockIssue.groupPath,
      iid: mockIssue.iid,
      issuableType: TYPE_ISSUE,
      issuableAttribute: IssuableAttributeType.Iteration,
    });
  });
});
