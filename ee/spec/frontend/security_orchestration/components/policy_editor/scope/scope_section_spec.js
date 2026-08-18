import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import waitForPromises from 'helpers/wait_for_promises';
import ScopeSection from 'ee/security_orchestration/components/policy_editor/scope/scope_section.vue';
import ComplianceFrameworkSelector from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_selector.vue';
import AttributeRows from 'ee/security_orchestration/components/policy_editor/scope/attribute_rows.vue';
import GroupSelector from 'ee/security_orchestration/components/policy_editor/scope/group_selector.vue';
import ProjectSelector from 'ee/security_orchestration/components/policy_editor/scope/project_selector.vue';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import SectionAlert from 'ee/security_orchestration/components/policy_editor/scope/section_alert.vue';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  ALL_PROJECTS_IN_GROUP,
  CSP_SCOPE_TYPE_LISTBOX_ITEMS,
  CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS,
  PROJECTS_WITH_FRAMEWORK,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  EXCEPT_GROUPS,
  EXCEPT_PERSONAL_PROJECTS,
  WITHOUT_EXCEPTIONS,
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  ALL_PROJECTS_IN_LINKED_GROUPS,
  SECURITY_CATEGORIES,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import {
  mockLinkedSppItemsResponse,
  defaultPageInfo,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';

describe('PolicyScope', () => {
  let wrapper;
  let requestHandler;

  const defaultAssignedPolicyProject = { fullPath: 'path/to/policy-project', branch: 'main' };
  const createHandler = ({ projects = [], namespaces = [] } = {}) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: '1',
          securityPolicyProjectLinkedProjects: {
            nodes: projects,
            pageInfo: { ...defaultPageInfo },
          },
          securityPolicyProjectLinkedGroups: {
            nodes: namespaces,
            pageInfo: { ...defaultPageInfo },
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getSppLinkedProjectsGroups, requestHandler]]);
  };

  const createComponent = ({
    propsData,
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(ScopeSection, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        policyScope: {},
        ...propsData,
      },
      provide: {
        assignedPolicyProject: defaultAssignedPolicyProject,
        designatedAsCsp: false,
        enabledExperiments: ['security_attributes_policy_scope'],
        existingPolicy: null,
        namespacePath: 'gitlab-org',
        namespaceType: NAMESPACE_TYPES.GROUP,
        rootNamespacePath: 'gitlab-org-root',
        ...provide,
      },
      stubs: {
        GlSprintf,
        SectionAlert,
        LoaderWithMessage,
      },
    });
  };

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findComplianceFrameworkSelector = () => wrapper.findComponent(ComplianceFrameworkSelector);
  const findProjectSelector = () => wrapper.findComponent(ProjectSelector);
  const findGroupSelector = () => wrapper.findComponent(GroupSelector);
  const findProjectScopeTypeDropdown = () => wrapper.findComponentByTestId('project-scope-type');
  const findPolicyScopeProjectText = () => wrapper.findByTestId('policy-scope-project-text');
  const findLoader = () => wrapper.findComponent(LoaderWithMessage);
  const findSectionAlert = () => wrapper.findComponent(SectionAlert);
  const findLoadingText = () => wrapper.findByTestId('loading-text');
  const findErrorMessage = () => wrapper.findByTestId('policy-scope-project-error');
  const findErrorMessageText = () => wrapper.findByTestId('policy-scope-project-error-text');
  const findDefaultScopeSelector = () => wrapper.findComponentByTestId('default-scope-selector');
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findAttributeRows = () => wrapper.findComponent(AttributeRows);

  beforeEach(() => {
    createComponent();
  });

  it('should render framework dropdown in initial state', () => {
    expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
    expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
    expect(findProjectSelector().exists()).toBe(true);
    expect(findProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);

    expect(findComplianceFrameworkSelector().exists()).toBe(false);
    expect(findGlAlert().exists()).toBe(false);
  });

  it('should not check linked items on group level', async () => {
    await waitForPromises();

    expect(findLoader().exists()).toBe(false);
    expect(findProjectScopeTypeDropdown().exists()).toBe(true);
    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findPolicyScopeProjectText().exists()).toBe(false);
  });

  it('should change scope and reset it', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

    expect(findComplianceFrameworkSelector().props('withItemsCount')).toBe(true);
    expect(findComplianceFrameworkSelector().exists()).toBe(true);

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
    ]);

    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    expect(findProjectSelector().exists()).toBe(true);
    expect(wrapper.text()).toBe('Apply this policy to');
    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
      [
        {
          projects: {
            including: [],
          },
        },
      ],
    ]);
  });

  it('should select excluding projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_GROUP);

    expect(findProjectSelector().exists()).toBe(true);

    await findProjectSelector().vm.$emit('select-exception-type', EXCEPT_PROJECTS);

    findProjectSelector().vm.$emit('changed', {
      projects: {
        excluding: [{ id: 1 }, { id: 2 }],
      },
    });

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            excluding: [],
          },
        },
      ],
      [{ projects: { excluding: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select including projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    findProjectSelector().vm.$emit('changed', {
      projects: {
        including: [{ id: 1 }, { id: 2 }],
      },
    });

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            including: [],
          },
        },
      ],
      [{ projects: { including: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select compliance frameworks', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);
    findComplianceFrameworkSelector().vm.$emit('select', ['id1', 'id2']);

    expect(wrapper.emitted('changed')).toEqual([
      [{ compliance_frameworks: [] }],
      [{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }],
    ]);
  });

  describe('existing policy scope', () => {
    it('should render existing compliance frameworks', () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }],
          },
        },
      });

      expect(findComplianceFrameworkSelector().exists()).toBe(true);
      expect(findComplianceFrameworkSelector().props('disabled')).toBe(false);
      expect(findComplianceFrameworkSelector().props('selectedFrameworkIds')).toEqual([
        'id1',
        'id2',
      ]);

      expect(wrapper.text()).toBe('Apply this policy to named');
    });

    it('should render existing excluding projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkSelector().exists()).toBe(false);

      expect(findProjectSelector().props('exceptionType')).toBe(EXCEPT_PROJECTS);
      expect(findProjectSelector().exists()).toBe(true);
      expect(findProjectSelector().props('projects')).toEqual({
        excluding: [{ id: 'id1' }, { id: 'id2' }],
      });
    });

    it('should render existing including projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkSelector().exists()).toBe(false);
      expect(findProjectSelector().exists()).toBe(true);
      expect(wrapper.text()).toBe('Apply this policy to');
      expect(findProjectSelector().props('projects')).toEqual({
        including: [{ id: 'id1' }, { id: 'id2' }],
      });
    });

    it('should render alert message for projects dropdown', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      await findProjectSelector().vm.$emit('error');
      expect(findGlAlert().exists()).toBe(true);
    });

    it('should render alert message for compliance framework dropdown', async () => {
      await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

      await findComplianceFrameworkSelector().vm.$emit('framework-query-error');
      expect(findGlAlert().exists()).toBe(true);
    });
  });

  describe('project level', () => {
    describe('security policy project', () => {
      const createComponentForSPP = async ({ provide = {} } = {}) => {
        createComponent({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            ...provide,
          },
          handler: createHandler({
            projects: [
              { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
              { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
            ],
            groups: [
              { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
              { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
            ],
          }),
        });

        await waitForPromises();
      };

      describe('new policy', () => {
        beforeEach(async () => {
          await createComponentForSPP();
        });

        it('does not show the default scope option', () => {
          expect(findDefaultScopeSelector().exists()).toBe(false);
        });

        it('shows the enabled policy scope selector', () => {
          expect(findPolicyScopeProjectText().exists()).toBe(false);
          expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
          expect(findProjectSelector().exists()).toBe(true);
        });
      });

      describe('project level with policy group scope', () => {
        it('renders group selector when SPP has linked items', async () => {
          await createComponentForSPP();

          await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);
          expect(findGroupSelector().exists()).toBe(true);
          expect(findGroupSelector().props('fullPath')).toBe('gitlab-org');
        });

        it('selects policy group scope on project level for SPP', async () => {
          await createComponentForSPP();

          await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);
          await findGroupSelector().vm.$emit('changed', {
            groups: {
              including: [{ id: 1 }, { id: 2 }],
            },
          });

          expect(wrapper.emitted('changed')).toEqual([
            [{ projects: { excluding: [] } }],
            [{ groups: { including: [] } }],
            [{ groups: { including: [{ id: 1 }, { id: 2 }] } }],
          ]);
        });

        it('does not render group selector when SPP has no linked items', async () => {
          createComponent({
            provide: {
              namespaceType: NAMESPACE_TYPES.PROJECT,
            },
          });

          await waitForPromises();

          expect(findProjectScopeTypeDropdown().exists()).toBe(false);
          expect(findPolicyScopeProjectText().text()).toBe('Apply this policy to current project.');
        });
      });

      describe('existing policy', () => {
        describe('no existing policy scope', () => {
          beforeEach(async () => {
            await createComponentForSPP({ provide: { existingPolicy: { name: 'A' } } });
          });

          it('displays the default scope and checks it', () => {
            expect(findDefaultScopeSelector().exists()).toBe(true);
            expect(findDefaultScopeSelector().attributes('checked')).toBe('true');
          });

          it('disables the scope dropdowns when default scope is set', () => {
            expect(findProjectScopeTypeDropdown().exists()).toBe(true);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(true);
            expect(findProjectSelector().props('disabled')).toBe(true);
          });

          it('enables the scope dropdowns when default scope is unchecked', async () => {
            await findDefaultScopeSelector().vm.$emit('input', false);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
            expect(findProjectSelector().props('disabled')).toBe(false);
          });

          it('adds the policy scope yaml when default scope is unchecked', async () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
            await findDefaultScopeSelector().vm.$emit('change');
            expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
          });

          it('does not emit default policy scope on load', () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
          });

          it('resets the selectors when default scope is checked', async () => {
            await findDefaultScopeSelector().vm.$emit('change');
            await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(SPECIFIC_PROJECTS);

            await findDefaultScopeSelector().vm.$emit('change', true);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
            expect(findProjectSelector().exists()).toBe(true);
          });
        });
      });
    });

    it('should check linked items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(requestHandler).toHaveBeenCalledTimes(1);
    });

    it('show text message for project without linked items', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().text()).toBe('Apply this policy to current project.');
    });

    it('show compliance framework selector for projects with links', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().exists()).toBe(false);
      expect(findProjectScopeTypeDropdown().exists()).toBe(true);
      expect(findProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
    });

    it('shows loading state', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findLoader().exists()).toBe(true);
      expect(findLoadingText().text()).toBe('Fetching the scope information.');
    });

    it('shows error message when spp query fails', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: jest.fn().mockRejectedValue({}),
      });

      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessageText().text()).toBe(
        'Failed to fetch the scope information. Please refresh the page to try again.',
      );
      expect(findIcon().props('name')).toBe('status_warning');
    });

    it('emits default policy scope on project level for SPP with multiple dependencies', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
    });

    it('does not emit default policy scope on group level', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toBeUndefined();
    });
  });

  describe('namespace', () => {
    it.each`
      namespaceType              | expectedResult
      ${NAMESPACE_TYPES.GROUP}   | ${'gitlab-org-root'}
      ${NAMESPACE_TYPES.PROJECT} | ${'gitlab-org-root'}
    `('queries different namespaces on $namespaceType level', async ({ namespaceType }) => {
      createComponent({
        provide: {
          namespaceType,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();
      await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

      expect(findProjectSelector().exists()).toBe(true);
    });
  });

  describe('error message and validation', () => {
    const findScopeAlert = () => findSectionAlert().findComponent(GlAlert);

    it('should show alert when compliance frameworks are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [],
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);
      expect(findComplianceFrameworkSelector().props('showError')).toBe(false);

      await findComplianceFrameworkSelector().vm.$emit('select', ['id1']);

      expect(findScopeAlert().exists()).toBe(true);
      expect(findComplianceFrameworkSelector().props('showError')).toBe(true);
    });

    it('should show alert when specific projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findProjectSelector().vm.$emit('changed', { excluding: ['id1'] });

      expect(findScopeAlert().exists()).toBe(true);
      expect(findSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: true,
        projectEmpty: true,
        groupsEmpty: true,
        projectScopeType: SPECIFIC_PROJECTS,
      });
    });

    it('should show alert when excluding projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findProjectSelector().vm.$emit('select-exception-type', EXCEPT_PROJECTS);
      await findProjectSelector().vm.$emit('changed', { excluding: ['id1'] });

      expect(findScopeAlert().exists()).toBe(true);

      expect(findSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: false,
        projectEmpty: true,
        groupsEmpty: true,
        projectScopeType: ALL_PROJECTS_IN_GROUP,
      });
    });
  });

  describe('policy group scope', () => {
    describe('initial selection', () => {
      beforeEach(() => {
        createComponent();
      });

      it('has group scope type in scope dropdown', () => {
        expect(findProjectScopeTypeDropdown().props('items')).toEqual(
          PROJECT_SCOPE_TYPE_LISTBOX_ITEMS.filter((i) => i.value !== SECURITY_CATEGORIES),
        );
      });

      it('should select including groups', async () => {
        await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);

        expect(findProjectSelector().exists()).toBe(false);
        expect(findGroupSelector().exists()).toBe(true);

        findGroupSelector().vm.$emit('changed', {
          groups: {
            including: [{ id: 1 }, { id: 2 }],
          },
        });

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              groups: {
                including: [],
              },
            },
          ],
          [{ groups: { including: [{ id: 1 }, { id: 2 }] } }],
        ]);
      });

      it('should select including groups and project exceptions', async () => {
        await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);

        expect(findProjectSelector().exists()).toBe(false);
        expect(findGroupSelector().exists()).toBe(true);

        findGroupSelector().vm.$emit('changed', {
          groups: {
            including: [{ id: 1 }, { id: 2 }],
          },
          projects: {
            excluding: [{ id: 1 }, { id: 2 }],
          },
        });

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              groups: {
                including: [],
              },
            },
          ],
          [
            {
              groups: { including: [{ id: 1 }, { id: 2 }] },
              projects: { excluding: [{ id: 1 }, { id: 2 }] },
            },
          ],
        ]);
      });

      it('does not default to EXCEPT_PERSONAL_PROJECTS', () => {
        expect(findProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
        expect(wrapper.emitted('changed')).toBeUndefined();
      });
    });

    describe('selected groups', () => {
      it('renders existing policy group scope', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [],
              },
            },
          },
        });

        expect(findGroupSelector().exists()).toBe(true);
        expect(findProjectSelector().exists()).toBe(false);
      });

      it('renders existing policy group scope with selected groups', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findGroupSelector().exists()).toBe(true);
        expect(findGroupSelector().props('groups')).toEqual({
          including: [{ id: 1 }, { id: 2 }],
        });
        expect(findGroupSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
        expect(findProjectSelector().exists()).toBe(false);
      });

      it('renders existing policy group scope with selected groups and projects', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
              projects: {
                excluding: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findGroupSelector().exists()).toBe(true);
        expect(findGroupSelector().props('groups')).toEqual({
          including: [{ id: 1 }, { id: 2 }],
        });
        expect(findGroupSelector().props('projects')).toEqual({
          excluding: [{ id: 1 }, { id: 2 }],
        });
        expect(findGroupSelector().props('exceptionType')).toBe(EXCEPT_PROJECTS);
        expect(findProjectSelector().exists()).toBe(false);
      });

      it('renders group scope selector even with including projects property', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
              projects: {
                including: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findGroupSelector().exists()).toBe(true);
        expect(findProjectSelector().exists()).toBe(false);
      });
    });
  });

  describe('global compliance security policies (CSP) group', () => {
    describe('scope type selection', () => {
      beforeEach(() => {
        createComponent({ provide: { designatedAsCsp: true } });
      });

      it('renders scope dropdown items', () => {
        expect(findProjectScopeTypeDropdown().props('items')).toEqual(
          CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS.filter((i) => i.value !== SECURITY_CATEGORIES),
        );
      });

      it('displays scope text as toggle text', () => {
        expect(findProjectScopeTypeDropdown().props('toggleText')).toBe(
          'all projects in this instance',
        );
      });

      it('renders ALL_PROJECTS_IN_GROUP as default selected value', () => {
        expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
      });

      it('displays exception dropdown by default', () => {
        expect(findProjectSelector().exists()).toBe(true);
      });

      it('defaults to EXCEPT_PERSONAL_PROJECTS', () => {
        expect(findProjectSelector().props('exceptionType')).toBe(EXCEPT_PERSONAL_PROJECTS);
        expect(wrapper.emitted('changed')).toEqual([
          [{ projects: { excluding: [{ type: 'personal' }] } }],
        ]);
      });

      it('renders project selector', () => {
        createComponent({
          provide: { designatedAsCsp: true },
          propsData: {
            policyScope: {
              groups: { excluding: [{ id: 1 }] },
            },
          },
        });

        expect(findProjectSelector().props('groupExceptionType')).toBe(EXCEPT_GROUPS);
        expect(findProjectSelector().props('projectScopeType')).toBe(ALL_PROJECTS_IN_GROUP);
        expect(findProjectSelector().props('groups')).toEqual({
          excluding: [{ id: 1 }],
        });
      });
    });

    describe('existing policies', () => {
      it('does not override existing policy scope', () => {
        createComponent({
          provide: { designatedAsCsp: true, existingPolicy: null },
          propsData: {
            policyScope: {
              projects: { excluding: [{ id: 1 }] },
            },
          },
        });

        expect(findProjectSelector().props('exceptionType')).toBe(EXCEPT_PROJECTS);
        expect(wrapper.emitted('changed')).toBeUndefined();
      });

      it('does not set default for existing policies', () => {
        createComponent({
          provide: { designatedAsCsp: true, existingPolicy: { name: 'Existing' } },
        });

        expect(findProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
        expect(wrapper.emitted('changed')).toBeUndefined();
      });

      it('detects and displays personal project exclusion', () => {
        createComponent({
          provide: { designatedAsCsp: true },
          propsData: {
            policyScope: {
              projects: {
                excluding: [{ type: 'personal' }],
              },
            },
          },
        });

        expect(findProjectSelector().props('exceptionType')).toBe(EXCEPT_PERSONAL_PROJECTS);
        expect(findProjectSelector().props('projects')).toEqual({
          excluding: [{ type: 'personal' }],
        });
      });

      it('handles mixed exclusions with personal projects and specific projects', () => {
        createComponent({
          provide: { designatedAsCsp: true },
          propsData: {
            policyScope: {
              projects: {
                excluding: [{ type: 'personal' }, { id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findProjectSelector().props('exceptionType')).toBe(EXCEPT_PERSONAL_PROJECTS);
      });
    });

    it('shows CSP group scope dropdown items if groups are present', () => {
      createComponent({
        propsData: { policyScope: { groups: { including: [{ id: 3 }] } } },
        provide: { designatedAsCsp: true },
      });

      expect(findProjectScopeTypeDropdown().props('items')).toEqual(
        CSP_SCOPE_TYPE_LISTBOX_ITEMS.filter((i) => i.value !== SECURITY_CATEGORIES),
      );
    });

    describe('scope selection behavior', () => {
      it('renders exception dropdown when instance scope is selected', async () => {
        createComponent({ provide: { designatedAsCsp: true } });

        await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_GROUP);

        expect(findProjectSelector().exists()).toBe(true);
      });

      it('updates toggle text when scope changes in CSP context', async () => {
        createComponent({ provide: { designatedAsCsp: true } });

        await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

        expect(findProjectScopeTypeDropdown().props('toggleText')).toBe('specific projects');
      });

      it('handles select-group-exception-type event from ProjectSelector', async () => {
        createComponent({ provide: { designatedAsCsp: true } });

        await findProjectSelector().vm.$emit('select-group-exception-type', EXCEPT_GROUPS);

        expect(findProjectSelector().props('groupExceptionType')).toBe(EXCEPT_GROUPS);
      });
    });
  });

  describe('security categories scope', () => {
    describe('when feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });
      });

      it('lists Security categories option in the scope-type dropdown', () => {
        const items = findProjectScopeTypeDropdown().props('items');
        expect(items.some((i) => i.value === SECURITY_CATEGORIES)).toBe(true);
      });

      it('labels the Security categories option as "security attributes"', () => {
        const items = findProjectScopeTypeDropdown().props('items');
        const categoryItem = items.find((i) => i.value === SECURITY_CATEGORIES);
        expect(categoryItem.text).toBe('security attributes');
      });

      it('does not render AttributeRows when another scope type is selected', () => {
        expect(findAttributeRows().exists()).toBe(false);
      });

      describe('when Security categories is selected', () => {
        beforeEach(async () => {
          await findProjectScopeTypeDropdown().vm.$emit('select', SECURITY_CATEGORIES);
        });

        it('renders AttributeRows', () => {
          expect(findAttributeRows().exists()).toBe(true);
        });

        it('shows "security attributes" as the toggle text', () => {
          expect(findProjectScopeTypeDropdown().props('toggleText')).toBe('security attributes');
        });

        it('renders the categories-specific "Apply this policy to" copy', () => {
          expect(wrapper.text()).toBe('Apply this policy to');
        });

        it('hides the framework, group, and project selectors', () => {
          expect(findComplianceFrameworkSelector().exists()).toBe(false);
          expect(findProjectSelector().exists()).toBe(false);
          expect(findGroupSelector().exists()).toBe(false);
        });

        it('emits an empty scope payload on selection so AttributeRows starts fresh', () => {
          expect(wrapper.emitted('changed').at(-1)).toEqual([{}]);
        });

        it('forwards disabled, isDirty, and policyScope props to AttributeRows', () => {
          expect(findAttributeRows().props('disabled')).toBe(false);
          expect(findAttributeRows().props('isDirty')).toBe(false);
          expect(findAttributeRows().props('policyScope')).toEqual({});
        });

        it('emits the AttributeRows payload as-is on @changed', () => {
          findAttributeRows().vm.$emit('changed', {
            business_impact: { including: [{ id: 1 }] },
          });

          expect(wrapper.emitted('changed').at(-1)).toEqual([
            { business_impact: { including: [{ id: 1 }] } },
          ]);
        });

        it('shows the alert when AttributeRows emits @error', async () => {
          await findAttributeRows().vm.$emit('error');

          expect(findGlAlert().exists()).toBe(true);
        });

        it('clears the category scope when switching away to a structural type', async () => {
          findAttributeRows().vm.$emit('changed', {
            business_impact: { including: [{ id: 1 }] },
          });

          await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

          expect(wrapper.emitted('changed').at(-1)).toEqual([{ projects: { including: [] } }]);
        });
      });
    });

    describe('when the security_attributes_policy_scope experiment is disabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: { securityAttributesPolicyScope: true },
            enabledExperiments: [],
          },
        });
      });

      it('does not list Security categories in the scope-type dropdown', () => {
        const items = findProjectScopeTypeDropdown().props('items');
        expect(items.some((i) => i.value === SECURITY_CATEGORIES)).toBe(false);
      });

      it('does not render AttributeRows', () => {
        expect(findAttributeRows().exists()).toBe(false);
      });
    });

    describe('when feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: { securityAttributesPolicyScope: false },
          },
        });
      });

      it('does not list Security categories in the scope-type dropdown', () => {
        const items = findProjectScopeTypeDropdown().props('items');
        expect(items.some((i) => i.value === SECURITY_CATEGORIES)).toBe(false);
      });

      it('does not render AttributeRows', () => {
        expect(findAttributeRows().exists()).toBe(false);
      });

      it('hydrates a category-only saved scope to ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: {
            policyScope: {
              business_impact: { including: [{ id: 1 }] },
            },
          },
          provide: {
            glFeatures: { securityAttributesPolicyScope: false },
          },
        });

        expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
        expect(findAttributeRows().exists()).toBe(false);
      });
    });

    describe('hydration', () => {
      it('selects Security categories when policyScope has only category keys', async () => {
        createComponent({
          propsData: {
            policyScope: {
              business_impact: { including: [{ id: 1 }] },
            },
          },
          provide: {
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });

        await waitForPromises();

        expect(findProjectScopeTypeDropdown().props('selected')).toBe(SECURITY_CATEGORIES);
        expect(findAttributeRows().exists()).toBe(true);
        expect(findAttributeRows().props('policyScope')).toEqual({
          business_impact: { including: [{ id: 1 }] },
        });
      });

      it('does not select Security categories for an unrecognized key, falling back to ALL_PROJECTS_IN_GROUP', () => {
        createComponent({
          propsData: {
            policyScope: {
              unrecognized_key: { including: [{ id: 1 }] },
            },
          },
          provide: {
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });

        expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
        expect(findAttributeRows().exists()).toBe(false);
      });

      it('selects a structural scope type when policyScope has structural keys', () => {
        createComponent({
          propsData: {
            policyScope: {
              projects: { including: [{ id: 'id1' }] },
            },
          },
          provide: {
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });

        expect(findProjectScopeTypeDropdown().props('selected')).toBe(SPECIFIC_PROJECTS);
        expect(findAttributeRows().exists()).toBe(false);
      });
    });

    describe('in CSP context with feature flag enabled', () => {
      it('lists Security categories option with "security attributes" label', () => {
        createComponent({
          provide: {
            designatedAsCsp: true,
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });

        const items = findProjectScopeTypeDropdown().props('items');
        const categoryItem = items.find((i) => i.value === SECURITY_CATEGORIES);
        expect(categoryItem).toBeDefined();
        expect(categoryItem.text).toBe('security attributes');
      });

      it('lists Security categories option when CSP has linked groups', () => {
        createComponent({
          provide: {
            designatedAsCsp: true,
            glFeatures: { securityAttributesPolicyScope: true },
          },
          propsData: { policyScope: { groups: { including: [{ id: 3 }] } } },
        });

        const items = findProjectScopeTypeDropdown().props('items');
        expect(items.some((i) => i.value === SECURITY_CATEGORIES)).toBe(true);
      });

      it('shows "security attributes" as toggle text when selected', async () => {
        createComponent({
          provide: {
            designatedAsCsp: true,
            glFeatures: { securityAttributesPolicyScope: true },
          },
        });

        await findProjectScopeTypeDropdown().vm.$emit('select', SECURITY_CATEGORIES);

        expect(findProjectScopeTypeDropdown().props('toggleText')).toBe('security attributes');
        expect(findAttributeRows().exists()).toBe(true);
      });
    });

    describe('when at project level', () => {
      it('renders AttributeRows when Security categories is selected', async () => {
        createComponent({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            glFeatures: { securityAttributesPolicyScope: true },
          },
          handler: mockLinkedSppItemsResponse({
            projects: [
              { id: '1', name: 'name1', fullPath: 'fullPath1' },
              { id: '2', name: 'name2', fullPath: 'fullPath2' },
            ],
          }),
        });

        await waitForPromises();

        await findProjectScopeTypeDropdown().vm.$emit('select', SECURITY_CATEGORIES);

        expect(findAttributeRows().exists()).toBe(true);
      });
    });
  });
});
