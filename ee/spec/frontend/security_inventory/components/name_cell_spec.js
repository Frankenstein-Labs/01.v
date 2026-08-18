import { GlIcon, GlLink, GlTruncate } from '@gitlab/ui';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockProjects, mockSubgroups } from '../mock_data';

describe('NameCell', () => {
  let wrapper;

  const mockProject = mockProjects[0];
  const mockGroup = mockSubgroups[0];

  const createComponent = (prop = {}) => {
    wrapper = shallowMountExtended(NameCell, {
      propsData: { item: mockProject, showSearchParam: false, ...prop },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLink = () => wrapper.findComponent(GlLink);
  const findAvatar = () => wrapper.findComponent(ProjectAvatar);
  const findTruncate = () => wrapper.findComponent(GlTruncate);
  const findByTestId = (id) => wrapper.findByTestId(id);

  describe('project view', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('project');
      expect(findByTestId('name-cell-item-name').text()).toBe(mockProject.name);
    });

    it('does not render full path for projects only', () => {
      expect(findByTestId('name-cell-item-path').exists()).toBe(false);
      expect(findTruncate().exists()).toBe(false);
    });

    it('renders full path while searching for projects only', () => {
      createComponent({ showSearchParam: true });
      expect(findTruncate().props('text')).toBe('flightjs');
    });

    it('renders the subgroup path as a link when a subgroupHref is provided', () => {
      createComponent({ showSearchParam: true, subgroupHref: '#flightjs' });
      expect(findLink().attributes('href')).toBe('#flightjs');
      expect(findTruncate().props('text')).toBe('flightjs');
    });

    it('renders the subgroup path as plain text when no subgroupHref is provided', () => {
      createComponent({ showSearchParam: true });
      expect(findByTestId('name-cell-item-path').exists()).toBe(true);
      expect(findLink().exists()).toBe(false);
    });

    it('does not render a link', () => {
      expect(findLink().exists()).toBe(false);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockProject.id,
        projectName: mockProject.name,
        projectAvatarUrl: mockProject.avatarUrl,
      });
    });
  });

  describe('with hideIcons', () => {
    beforeEach(() => {
      createComponent({ hideIcons: true });
    });

    it('does not render the leading icon', () => {
      expect(findIcon().exists()).toBe(false);
    });

    it('still renders the item name', () => {
      expect(findByTestId('name-cell-item-name').text()).toBe(mockProject.name);
    });
  });

  describe('group view', () => {
    beforeEach(() => {
      createComponent({ item: mockGroup });
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('subgroup');
      expect(wrapper.text()).toContain(mockGroup.name);
      expect(wrapper.text()).toContain(
        `${mockGroup.projectsCount} project, ${mockGroup.descendantGroupsCount} subgroups`,
      );
    });

    it('does not render full path for groups', () => {
      expect(findByTestId('name-cell-item-path').exists()).toBe(false);
    });

    it('renders the correct link', () => {
      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes('href')).toBe(`#${mockGroup.fullPath}`);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockGroup.id,
        projectName: mockGroup.name,
        projectAvatarUrl: mockGroup.avatarUrl,
      });
    });
  });
});
