import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RolesExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/roles_exceptions.vue';
import PolicyExceptionsLoader from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions_loader.vue';
import groupCustomRoles from 'ee/security_orchestration/graphql/queries/group_custom_roles.query.graphql';
import projectCustomRoles from 'ee/security_orchestration/graphql/queries/project_custom_roles.query.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('RolesExceptions', () => {
  let wrapper;
  let mockApollo;

  const namespacePath = 'path/to/namespace';
  const namespaceType = NAMESPACE_TYPES.PROJECT;

  const mockCustomRoles = [
    {
      id: 'gid://gitlab/MemberRole/1',
      name: 'Custom Role 1',
      baseAccessLevel: { stringValue: 'REPORTER' },
      enabledPermissions: { edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] },
    },
    {
      id: 'gid://gitlab/MemberRole/2',
      name: 'Custom Role 2',
      baseAccessLevel: { stringValue: 'DEVELOPER' },
      enabledPermissions: { edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] },
    },
  ];

  const createMockApolloProvider = (customRolesHandler) => {
    Vue.use(VueApollo);

    return createMockApollo([
      [groupCustomRoles, jest.fn()],
      [projectCustomRoles, customRolesHandler],
    ]);
  };

  const createSuccessHandler = (customRoles = mockCustomRoles) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          memberRoles: {
            nodes: customRoles,
          },
          __typename: 'Project',
        },
      },
    });

  const standardRoles = ['maintainer', 'developer', 'reporter'];

  const createFailureHandler = () => jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const createComponent = ({
    propsData = {},
    apolloHandler = createSuccessHandler(),
    provide = {},
  } = {}) => {
    mockApollo = createMockApolloProvider(apolloHandler);

    wrapper = shallowMountExtended(RolesExceptions, {
      apolloProvider: mockApollo,
      propsData,
      provide: {
        namespacePath,
        namespaceType,
        ...provide,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findLoader = () => wrapper.findComponent(PolicyExceptionsLoader);
  const findRoleItems = () => wrapper.findAll('li');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct header level', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('displays correct title with zero count when no roles provided', () => {
      expect(findAccordionItem().props('title')).toBe('Roles (0)');
    });

    it('does not show loading state initially', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('does not render any role items when arrays are empty', () => {
      expect(findRoleItems()).toHaveLength(0);
    });
  });

  describe('with standard roles', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          roles: standardRoles,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Roles (3)');
    });

    it('renders role items for each standard role', () => {
      const roleItems = findRoleItems();
      expect(roleItems).toHaveLength(3);
      expect(roleItems.at(0).text()).toBe('maintainer');
      expect(roleItems.at(1).text()).toBe('developer');
      expect(roleItems.at(2).text()).toBe('reporter');
    });
  });

  describe('with custom roles', () => {
    const customRoles = [{ id: 1 }, { id: 2 }];

    beforeEach(() => {
      createComponent({
        propsData: {
          customRoles,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Roles (2)');
    });

    it('does not load custom roles initially', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('accordion interaction', () => {
    const customRoles = [{ id: 1 }, { id: 2 }];

    beforeEach(() => {
      createComponent({
        propsData: {
          customRoles,
        },
      });
    });

    it('loads custom roles when accordion is opened', async () => {
      const accordionItem = findAccordionItem();

      await accordionItem.vm.$emit('input', true);

      expect(findLoader().exists()).toBe(true);
      expect(findLoader().props('label')).toBe('Loading custom roles');

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
    });

    it('does not load custom roles when accordion is closed', () => {
      const accordionItem = findAccordionItem();

      accordionItem.vm.$emit('input', false);

      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('custom roles loading success', () => {
    const customRoles = [{ id: 1 }, { id: 2 }];

    beforeEach(async () => {
      createComponent({
        propsData: {
          customRoles,
        },
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();
    });

    it('displays loaded custom roles', () => {
      const roleItems = findRoleItems();
      expect(roleItems.at(0).text()).toBe('Custom Role 1');
      expect(roleItems.at(1).text()).toBe('Custom Role 2');
    });

    it('hides loading state after successful load', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('custom roles loading failure', () => {
    const customRoles = [{ id: 1 }, { id: 2 }];

    beforeEach(async () => {
      createComponent({
        propsData: {
          customRoles,
        },
        apolloHandler: createFailureHandler(),
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();
    });

    it('displays fallback custom role IDs when loading fails', () => {
      const roleItems = findRoleItems();
      expect(roleItems.at(0).text()).toBe('id: 1');
      expect(roleItems.at(1).text()).toBe('id: 2');
    });

    it('hides loading state after failed load', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });
});
