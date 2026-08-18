import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectSelector from 'ee/security_orchestration/components/policy_editor/scope/project_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';
import LinkedGroupsProjectsDropdown from 'ee/security_orchestration/components/shared/linked_groups_projects_dropdown.vue';
import EligibleProjectsDropdown from 'ee/security_orchestration/components/shared/eligible_projects_dropdown.vue';
import {
  generateMockProjects,
  generateMockGroups,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  EXCEPT_PROJECTS,
  EXCEPT_PERSONAL_PROJECTS,
  EXCEPT_GROUPS,
  ALL_PROJECTS_IN_GROUP,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { WITHOUT_EXCEPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import InstanceProjectsDropdown from 'ee/security_orchestration/components/shared/instance_projects_dropdown.vue';

describe('ProjectSelector', () => {
  let wrapper;

  const projects = generateMockProjects([1, 2]);
  const mappedProjects = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));
  const groups = generateMockGroups([3, 4]);
  const mappedGroups = groups.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectSelector, {
      propsData: {
        groupFullPath: 'gitlab-org',
        projects: { excluding: [] },
        ...propsData,
      },
      provide: {
        designatedAsCsp: false,
        assignedPolicyProject: null,
        namespaceType: NAMESPACE_TYPES.GROUP,
        ...provide,
      },
    });
  };

  const findExceptionTypeSelector = () => wrapper.findComponentByTestId('exception-type');
  const findGroupExceptionTypeSelector = () =>
    wrapper.findComponentByTestId('group-exception-type');
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findLinkedGroupsProjectsDropdown = () =>
    wrapper.findComponent(LinkedGroupsProjectsDropdown);
  const findEligibleProjectsDropdown = () => wrapper.findComponent(EligibleProjectsDropdown);
  const findInstanceProjectsDropdown = () => wrapper.findComponent(InstanceProjectsDropdown);
  const findScopedGroupsDropdown = () => wrapper.findComponent(ScopedGroupsDropdown);

  describe('default rendering', () => {
    it('renders exceptions type selector', () => {
      createComponent();

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });

    it('renders exceptions type selector with empty projects', () => {
      createComponent({
        propsData: { projects: {} },
      });

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });
  });

  describe('renders projects selector', () => {
    describe('non-csp group', () => {
      const mockAssignedPolicyProject = { fullPath: 'security/policy-project' };

      it('renders group projects selector when exception type is selected and no SPP assigned', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
        });

        expect(findGroupProjectsDropdown().exists()).toBe(true);
        expect(findGroupProjectsDropdown().props('withProjectCount')).toBe(true);
        expect(findInstanceProjectsDropdown().exists()).toBe(false);
        expect(findLinkedGroupsProjectsDropdown().exists()).toBe(false);
      });

      it('renders group projects selector when exceptions are disabled', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
        });

        expect(findExceptionTypeSelector().exists()).toBe(false);
        expect(findGroupProjectsDropdown().exists()).toBe(true);
        expect(findInstanceProjectsDropdown().exists()).toBe(false);
      });

      it('renders the correct exception options', () => {
        createComponent();

        const items = findExceptionTypeSelector().props('items');
        const itemValues = items.map((item) => item.value);

        expect(itemValues).toContain(WITHOUT_EXCEPTIONS);
        expect(itemValues).toContain(EXCEPT_PROJECTS);
        expect(itemValues).not.toContain(EXCEPT_PERSONAL_PROJECTS);
      });

      it('renders LinkedGroupsProjectsDropdown when SPP is assigned', () => {
        createComponent({
          propsData: {
            exceptionType: EXCEPT_PROJECTS,
          },
          provide: {
            assignedPolicyProject: mockAssignedPolicyProject,
          },
        });

        expect(findLinkedGroupsProjectsDropdown().exists()).toBe(true);
        expect(findGroupProjectsDropdown().exists()).toBe(false);
        expect(findInstanceProjectsDropdown().exists()).toBe(false);
      });

      it('renders GroupProjectsDropdown at project level even when SPP is assigned', () => {
        createComponent({
          propsData: {
            exceptionType: EXCEPT_PROJECTS,
          },
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            assignedPolicyProject: mockAssignedPolicyProject,
          },
        });

        expect(findGroupProjectsDropdown().exists()).toBe(true);
        expect(findLinkedGroupsProjectsDropdown().exists()).toBe(false);
      });

      it('selects projects from LinkedGroupsProjectsDropdown', () => {
        createComponent({
          propsData: {
            exceptionType: EXCEPT_PROJECTS,
          },
          provide: {
            assignedPolicyProject: mockAssignedPolicyProject,
          },
        });

        findLinkedGroupsProjectsDropdown().vm.$emit('select', projects);

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              projects: {
                excluding: mappedProjects,
              },
            },
          ],
        ]);
      });

      describe('securityPolicyEligibleProjectsDropdown feature flag', () => {
        const createAtGroupLevelWithSpp = (glFeatures) =>
          createComponent({
            propsData: { exceptionType: EXCEPT_PROJECTS },
            provide: {
              assignedPolicyProject: mockAssignedPolicyProject,
              glFeatures,
            },
          });

        it('renders EligibleProjectsDropdown when the flag is enabled', () => {
          createAtGroupLevelWithSpp({ securityPolicyEligibleProjectsDropdown: true });

          expect(findEligibleProjectsDropdown().exists()).toBe(true);
          expect(findLinkedGroupsProjectsDropdown().exists()).toBe(false);
        });

        it('renders LinkedGroupsProjectsDropdown when the flag is disabled', () => {
          createAtGroupLevelWithSpp({ securityPolicyEligibleProjectsDropdown: false });

          expect(findLinkedGroupsProjectsDropdown().exists()).toBe(true);
          expect(findEligibleProjectsDropdown().exists()).toBe(false);
        });
      });
    });

    describe('csp group', () => {
      it('renders instance projects selector when exception type is selected', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
          provide: { designatedAsCsp: true },
        });

        expect(findGroupProjectsDropdown().exists()).toBe(false);
        expect(findInstanceProjectsDropdown().exists()).toBe(true);
      });

      it('renders instance projects selector when exceptions are disabled', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp: true },
        });

        expect(findExceptionTypeSelector().exists()).toBe(false);
        expect(findGroupProjectsDropdown().exists()).toBe(false);
        expect(findInstanceProjectsDropdown().exists()).toBe(true);
      });

      it('does not show projects dropdown when EXCEPT_PERSONAL_PROJECTS is selected', () => {
        createComponent({
          propsData: {
            projects: {
              excluding: [{ type: 'personal' }],
            },
            exceptionType: EXCEPT_PERSONAL_PROJECTS,
          },
          provide: { designatedAsCsp: true },
        });

        expect(findInstanceProjectsDropdown().exists()).toBe(false);
        expect(findGroupProjectsDropdown().exists()).toBe(false);
      });

      it('renders the correct exception options', () => {
        createComponent({ provide: { designatedAsCsp: true } });

        const items = findExceptionTypeSelector().props('items');
        const itemValues = items.map((item) => item.value);

        expect(itemValues).toContain(WITHOUT_EXCEPTIONS);
        expect(itemValues).toContain(EXCEPT_PROJECTS);
        expect(itemValues).toContain(EXCEPT_PERSONAL_PROJECTS);
      });

      it('renders group exception type selector when projectScopeType is ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: { projectScopeType: ALL_PROJECTS_IN_GROUP },
          provide: { designatedAsCsp: true },
        });

        expect(findGroupExceptionTypeSelector().exists()).toBe(true);
      });

      it('does not render group exception type selector when projectScopeType is not ALL_PROJECTS_IN_GROUP', () => {
        createComponent({ provide: { designatedAsCsp: true } });

        expect(findGroupExceptionTypeSelector().exists()).toBe(false);
      });

      it('renders scoped groups dropdown when EXCEPT_GROUPS is selected and projectScopeType is ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
          provide: { designatedAsCsp: true },
        });

        expect(findScopedGroupsDropdown().exists()).toBe(true);
        expect(findScopedGroupsDropdown().props('useDescendantGroups')).toBe(false);
      });

      it('does not render scoped groups dropdown when WITHOUT_EXCEPTIONS is selected', () => {
        createComponent({
          propsData: {
            groupExceptionType: WITHOUT_EXCEPTIONS,
            projectScopeType: ALL_PROJECTS_IN_GROUP,
          },
          provide: { designatedAsCsp: true },
        });

        expect(findScopedGroupsDropdown().exists()).toBe(false);
      });

      it('falls back to WITHOUT_EXCEPTIONS text when groupExceptionType is invalid', () => {
        createComponent({
          propsData: {
            groupExceptionType: 'invalid_type',
            projectScopeType: ALL_PROJECTS_IN_GROUP,
          },
          provide: { designatedAsCsp: true },
        });

        expect(findGroupExceptionTypeSelector().props('toggleText')).toBe(
          'without group exceptions',
        );
      });
    });

    describe('non-csp group - group exception', () => {
      it('renders group exception type selector when projectScopeType is ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: { projectScopeType: ALL_PROJECTS_IN_GROUP },
          provide: { designatedAsCsp: false },
        });

        expect(findGroupExceptionTypeSelector().exists()).toBe(true);
      });

      it('does not render group exception type selector when projectScopeType is not ALL_PROJECTS_IN_GROUP', () => {
        createComponent({ provide: { designatedAsCsp: false } });

        expect(findGroupExceptionTypeSelector().exists()).toBe(false);
      });

      it('renders scoped groups dropdown with useDescendantGroups when EXCEPT_GROUPS is selected and projectScopeType is ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
          provide: { designatedAsCsp: false },
        });

        expect(findScopedGroupsDropdown().exists()).toBe(true);
        expect(findScopedGroupsDropdown().props('useDescendantGroups')).toBe(true);
      });

      it('does not render scoped groups dropdown when WITHOUT_EXCEPTIONS is selected', () => {
        createComponent({
          propsData: {
            groupExceptionType: WITHOUT_EXCEPTIONS,
            projectScopeType: ALL_PROJECTS_IN_GROUP,
          },
          provide: { designatedAsCsp: false },
        });

        expect(findScopedGroupsDropdown().exists()).toBe(false);
      });
    });
  });

  describe.each`
    title              | designatedAsCsp | findProjectSelector
    ${'non-csp group'} | ${false}        | ${findGroupProjectsDropdown}
    ${'csp group'}     | ${true}         | ${findInstanceProjectsDropdown}
  `('$title', ({ designatedAsCsp, findProjectSelector }) => {
    describe('project selection', () => {
      it('should select exception projects', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('select', projects);

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              projects: {
                excluding: mappedProjects,
              },
            },
          ],
        ]);
      });

      it('should select specific projects', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('select', projects);

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              projects: {
                including: mappedProjects,
              },
            },
          ],
        ]);
      });
    });

    describe('error state', () => {
      it('emits error when projects loading fails', () => {
        createComponent({
          propsData: {
            projects: {
              including: mappedProjects,
            },
          },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('projects-query-error');

        expect(wrapper.emitted('error')).toEqual([['Failed to load group projects']]);
      });

      it('does not render initial error state for a dropdown', () => {
        createComponent({
          propsData: {
            projects: {
              including: mappedProjects,
            },
          },
          provide: { designatedAsCsp },
        });
        expect(findProjectSelector().props('state')).toBe(true);
      });

      it('renders error state for a dropdown when form is dirty', () => {
        createComponent({
          propsData: {
            isDirty: true,
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp },
        });
        expect(findProjectSelector().props('state')).toBe(false);
      });
    });
  });

  describe('selected projects', () => {
    describe('non-csp group', () => {
      it.each`
        key            | projectType    | hasExceptions
        ${'excluding'} | ${'exception'} | ${true}
        ${'including'} | ${'specific'}  | ${false}
      `('renders selected $projectType projects', ({ key, hasExceptions }) => {
        createComponent({
          propsData: {
            projects: {
              [key]: mappedProjects,
            },
            exceptionType: EXCEPT_PROJECTS,
          },
        });

        expect(findExceptionTypeSelector().exists()).toBe(hasExceptions);
        expect(findGroupProjectsDropdown().props('selected')).toEqual([
          projects[0].id,
          projects[1].id,
        ]);
      });
    });

    describe('csp group', () => {
      it.each`
        key            | projectType    | hasExceptions
        ${'excluding'} | ${'exception'} | ${true}
        ${'including'} | ${'specific'}  | ${false}
      `('renders selected $projectType projects', ({ key, hasExceptions }) => {
        createComponent({
          propsData: {
            projects: {
              [key]: mappedProjects,
            },
            exceptionType: EXCEPT_PROJECTS,
          },
          provide: { designatedAsCsp: true },
        });

        expect(findExceptionTypeSelector().exists()).toBe(hasExceptions);
        expect(findInstanceProjectsDropdown().props('selected')).toEqual([1, 2]);
      });
    });

    it('filters out personal project type from project IDs', () => {
      createComponent({
        propsData: {
          projects: { excluding: [{ type: 'personal' }, ...mappedProjects] },
          exceptionType: EXCEPT_PROJECTS,
        },
        provide: { designatedAsCsp: true },
      });

      expect(findInstanceProjectsDropdown().exists()).toBe(true);
      expect(findInstanceProjectsDropdown().props('selected')).toEqual([1, 2]);
    });
  });

  describe('select exceptions', () => {
    it('selects exception type', () => {
      createComponent();

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PROJECTS]]);
    });
  });

  describe('reset selected projects', () => {
    it('should select exception type WITHOUT_EXCEPTIONS and reset exceptions', () => {
      createComponent({ propsData: { projects: { excluding: mappedProjects } } });

      findExceptionTypeSelector().vm.$emit('select', WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
      expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
    });

    it('should select exception type EXCEPT_PERSONAL_PROJECTS and set personal project exclusion', () => {
      createComponent({ provide: { designatedAsCsp: true } });

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PERSONAL_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PERSONAL_PROJECTS]]);
      expect(wrapper.emitted('changed')).toEqual([
        [{ projects: { excluding: [{ type: 'personal' }] } }],
      ]);
    });

    it('should select exception type EXCEPT_PROJECTS and reset exceptions', () => {
      createComponent({ provide: { designatedAsCsp: true } });

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PROJECTS]]);
      expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
    });
  });

  describe('group exceptions (CSP)', () => {
    it('should select group exception type EXCEPT_GROUPS', () => {
      createComponent({
        propsData: { projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: true },
      });

      findGroupExceptionTypeSelector().vm.$emit('select', EXCEPT_GROUPS);

      expect(wrapper.emitted('select-group-exception-type')).toEqual([[EXCEPT_GROUPS]]);
    });

    it('should select group exception type WITHOUT_EXCEPTIONS and reset excluded groups', () => {
      createComponent({
        propsData: {
          groups: { excluding: mappedGroups },
          groupExceptionType: EXCEPT_GROUPS,
          projectScopeType: ALL_PROJECTS_IN_GROUP,
        },
        provide: { designatedAsCsp: true },
      });

      findGroupExceptionTypeSelector().vm.$emit('select', WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted('select-group-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
      expect(wrapper.emitted('changed')).toEqual([[{ groups: { excluding: [] } }]]);
    });

    it('should select groups to exclude', () => {
      createComponent({
        propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: true },
      });

      findScopedGroupsDropdown().vm.$emit('select', groups);

      expect(wrapper.emitted('changed')).toEqual([[{ groups: { excluding: mappedGroups } }]]);
    });

    it('renders selected excluding groups', () => {
      createComponent({
        propsData: {
          groups: { excluding: mappedGroups },
          groupExceptionType: EXCEPT_GROUPS,
          projectScopeType: ALL_PROJECTS_IN_GROUP,
        },
        provide: { designatedAsCsp: true },
      });

      expect(findScopedGroupsDropdown().props('selected')).toEqual([groups[0].id, groups[1].id]);
    });

    it.each`
      excluding                                  | description
      ${[null, ...mappedGroups, null]}           | ${'null entries'}
      ${[{ type: 'personal' }, ...mappedGroups]} | ${'entries without an id'}
      ${'not-an-array'}                          | ${'a non-array value'}
    `('skips $description in excluding groups', ({ excluding }) => {
      createComponent({
        propsData: {
          groups: { excluding },
          groupExceptionType: EXCEPT_GROUPS,
          projectScopeType: ALL_PROJECTS_IN_GROUP,
        },
        provide: { designatedAsCsp: true },
      });

      const expected = Array.isArray(excluding) ? [groups[0].id, groups[1].id] : [];
      expect(findScopedGroupsDropdown().props('selected')).toEqual(expected);
    });

    it('emits error when groups loading fails', () => {
      createComponent({
        propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: true },
      });

      findScopedGroupsDropdown().vm.$emit('linked-items-query-error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load groups']]);
    });
  });

  describe('group exceptions (non-CSP)', () => {
    it('should select group exception type EXCEPT_GROUPS', () => {
      createComponent({
        propsData: { projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: false },
      });

      findGroupExceptionTypeSelector().vm.$emit('select', EXCEPT_GROUPS);

      expect(wrapper.emitted('select-group-exception-type')).toEqual([[EXCEPT_GROUPS]]);
    });

    it('should select group exception type WITHOUT_EXCEPTIONS and reset excluded groups', () => {
      createComponent({
        propsData: {
          groups: { excluding: mappedGroups },
          groupExceptionType: EXCEPT_GROUPS,
          projectScopeType: ALL_PROJECTS_IN_GROUP,
        },
        provide: { designatedAsCsp: false },
      });

      findGroupExceptionTypeSelector().vm.$emit('select', WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted('select-group-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
      expect(wrapper.emitted('changed')).toEqual([[{ groups: { excluding: [] } }]]);
    });

    it('should select groups to exclude', () => {
      createComponent({
        propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: false },
      });

      findScopedGroupsDropdown().vm.$emit('select', groups);

      expect(wrapper.emitted('changed')).toEqual([[{ groups: { excluding: mappedGroups } }]]);
    });

    it('renders selected excluding groups', () => {
      createComponent({
        propsData: {
          groups: { excluding: mappedGroups },
          groupExceptionType: EXCEPT_GROUPS,
          projectScopeType: ALL_PROJECTS_IN_GROUP,
        },
        provide: { designatedAsCsp: false },
      });

      expect(findScopedGroupsDropdown().props('selected')).toEqual([groups[0].id, groups[1].id]);
    });

    it('emits error when groups loading fails', () => {
      createComponent({
        propsData: { groupExceptionType: EXCEPT_GROUPS, projectScopeType: ALL_PROJECTS_IN_GROUP },
        provide: { designatedAsCsp: false },
      });

      findScopedGroupsDropdown().vm.$emit('linked-items-query-error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load groups']]);
    });
  });
});
