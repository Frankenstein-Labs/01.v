import { shallowMount } from '@vue/test-utils';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import { mockProjects, mockSubgroups } from '../mock_data';

describe('ToolCoverageCell', () => {
  let wrapper;

  const mockProject = mockProjects[0];
  const mockGroup = mockSubgroups[0];

  const createComponent = (props = {}) => {
    return shallowMount(ToolCoverageCell, {
      propsData: {
        item: {},
        ...props,
      },
    });
  };

  const findGroupToolCoverageIndicator = () => wrapper.findComponent(GroupToolCoverageIndicator);
  const findProjectToolCoverageIndicator = () =>
    wrapper.findComponent(ProjectToolCoverageIndicator);

  it('renders GroupToolCoverageIndicator for groups', () => {
    wrapper = createComponent({ item: mockGroup });

    expect(findGroupToolCoverageIndicator().exists()).toBe(true);
    expect(findProjectToolCoverageIndicator().exists()).toBe(false);
  });

  it('renders ProjectToolCoverageIndicator for projects', () => {
    wrapper = createComponent({ item: mockProject });

    expect(findGroupToolCoverageIndicator().exists()).toBe(false);
    expect(findProjectToolCoverageIndicator().exists()).toBe(true);
  });

  it('passes the correct props to ProjectToolCoverageIndicator', () => {
    wrapper = createComponent({ item: mockProject });

    const indicator = findProjectToolCoverageIndicator();
    expect(indicator.props('item')).toBe(mockProject);
  });

  it('passes the correct props to GroupToolCoverageIndicator', () => {
    wrapper = createComponent({ item: mockGroup });

    const indicator = findGroupToolCoverageIndicator();
    expect(indicator.props('item')).toBe(mockGroup);
  });
});
