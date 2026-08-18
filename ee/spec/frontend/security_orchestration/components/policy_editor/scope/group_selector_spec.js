import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupSelector from 'ee/security_orchestration/components/policy_editor/scope/group_selector.vue';
import {
  generateMockProjects,
  generateMockGroups,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { EXCEPT_PROJECTS } from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { WITHOUT_EXCEPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

describe('GroupSelector', () => {
  let wrapper;

  const groups = generateMockGroups([1, 2]);
  const mappedGroups = groups.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));
  const projects = generateMockProjects([3, 4]);
  const mappedProjects = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(GroupSelector, {
      propsData: {
        groupFullPath: 'gitlab-org',
        fullPath: 'gitlab-org',
        groups: { including: [] },
        ...propsData,
      },
    });
  };

  const findExceptionTypeSelector = () => wrapper.findComponentByTestId('exception-type');
  const findGroupsDropdown = () => wrapper.findComponentByTestId('groups-dropdown');
  const findProjectSelector = () => wrapper.findComponentByTestId('projects-dropdown');

  describe('default rendering', () => {
    it('renders exceptions type selector and group selector', () => {
      createComponent();

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupsDropdown().exists()).toBe(true);
      expect(findGroupsDropdown().props('includeDescendants')).toBe(true);
      expect(findGroupsDropdown().props('withProjectCount')).toBe(true);
    });
  });

  describe('project selector', () => {
    it('renders project selector', () => {
      createComponent({
        groups: { including: mappedGroups },
        exceptionType: EXCEPT_PROJECTS,
      });

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupsDropdown().exists()).toBe(true);
      expect(findProjectSelector().exists()).toBe(true);
    });

    it('does not render project selector when no groups were selected', () => {
      createComponent();

      expect(findExceptionTypeSelector().props('disabled')).toBe(true);
      expect(findProjectSelector().exists()).toBe(false);
    });

    it('does not render project selector when type is without exceptions', () => {
      createComponent({
        groups: { including: mappedGroups },
      });

      expect(findProjectSelector().exists()).toBe(false);
    });
  });

  describe('selection', () => {
    it('should select groups', () => {
      createComponent();

      findGroupsDropdown().vm.$emit('select', groups);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            groups: {
              including: mappedGroups,
            },
            projects: {
              excluding: [],
            },
          },
        ],
      ]);
    });

    it('should select without exceptions type when there are groups', async () => {
      createComponent();
      await findGroupsDropdown().vm.$emit('select', []);

      expect(wrapper.emitted('select-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
    });

    it('should select groups and projects', () => {
      createComponent({
        groups: { including: mappedGroups },
        exceptionType: EXCEPT_PROJECTS,
      });

      findProjectSelector().vm.$emit('select', projects);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            groups: {
              including: mappedGroups,
            },
            projects: {
              excluding: mappedProjects,
            },
          },
        ],
      ]);
    });
  });

  describe('selected groups', () => {
    it('renders selected groups', () => {
      createComponent({
        groups: { including: mappedGroups },
      });

      expect(findGroupsDropdown().props('selected')).toEqual([groups[0].id, groups[1].id]);
    });
  });

  describe('selected projects', () => {
    it('renders selected project exceptions', () => {
      createComponent({
        groups: { including: mappedGroups },
        projects: { excluding: mappedProjects },
        exceptionType: EXCEPT_PROJECTS,
      });

      expect(findGroupsDropdown().props('selected')).toEqual([groups[0].id, groups[1].id]);
      expect(findProjectSelector().props('selected')).toEqual([projects[0].id, projects[1].id]);
    });
  });

  describe('invalid values', () => {
    it('renders unselected dropdowns if values are invalid', () => {
      createComponent({
        groups: { excluding: mappedGroups },
        projects: { including: mappedProjects },
        exceptionType: EXCEPT_PROJECTS,
      });

      expect(findGroupsDropdown().props('selected')).toEqual([]);
      expect(findProjectSelector().exists()).toBe(true);
    });

    it('ignores null entries in the included groups', () => {
      createComponent({
        groups: { including: [{ id: 1 }, null, { id: 2 }] },
      });

      expect(findGroupsDropdown().props('selected')).toEqual([
        'gid://gitlab/Group/1',
        'gid://gitlab/Group/2',
      ]);
    });
  });

  describe('error state', () => {
    it('emits error when groups loading fails', () => {
      createComponent();

      findGroupsDropdown().vm.$emit('linked-items-query-error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load groups']]);
    });

    it('emits error when projects loading fails', () => {
      createComponent({
        groups: { including: mappedGroups },
        exceptionType: EXCEPT_PROJECTS,
      });

      findProjectSelector().vm.$emit('projects-query-error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load projects']]);
    });

    it('does not render initial error state for a dropdown', () => {
      createComponent();
      expect(findGroupsDropdown().props('state')).toBe(true);
    });

    it('renders error state for a dropdown when form is dirty', () => {
      createComponent({
        isDirty: true,
      });
      expect(findGroupsDropdown().props('state')).toBe(false);
    });
  });

  describe('exception type', () => {
    it('does not render exception list box when there are no groups', async () => {
      createComponent();

      await findGroupsDropdown().vm.$emit('loaded', []);

      expect(findExceptionTypeSelector().exists()).toBe(false);
    });

    it('should select exception type EXCEPT_PROJECTS', () => {
      createComponent();

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PROJECTS]]);
    });

    it('should select exception type WITHOUT_EXCEPTIONS', () => {
      createComponent({
        groups: { including: mappedGroups },
      });

      findExceptionTypeSelector().vm.$emit('select', WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            groups: {
              including: [{ id: 1 }, { id: 2 }],
            },
            projects: {
              excluding: [],
            },
          },
        ],
      ]);
    });
  });
});
