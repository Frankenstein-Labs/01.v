import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  EXCEPT_GROUPS,
  WITHOUT_EXCEPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import BlockGroupBranchModification from 'ee/security_orchestration/components/policy_editor/scan_result/settings/block_group_branch_modification.vue';
import { createMockGroups } from 'ee_jest/security_orchestration/mocks/mock_data';
import getSppLinkedGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';

jest.mock('~/alert');

describe('BlockGroupBranchModification', () => {
  let wrapper;
  let requestHandler;

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const defaultDescendantPageInfo = {
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const groups = [
    {
      id: '1',
      name: 'group1',
      fullPath: 'fullPath1',
      descendantGroups: { nodes: [], pageInfo: defaultDescendantPageInfo },
      fullName: 'fullName1',
      avatarUrl: 'avatarUrl1',
    },
    {
      id: '2',
      name: 'group2',
      fullPath: 'fullPath2',
      descendantGroups: { nodes: [], pageInfo: defaultDescendantPageInfo },
      fullName: 'fullName2',
      avatarUrl: 'avatarUrl2',
    },
    {
      id: '3',
      name: 'group2',
      fullPath: 'fullPath2',
      descendantGroups: { nodes: [], pageInfo: defaultDescendantPageInfo },
      fullName: 'fullName2',
      avatarUrl: 'avatarUrl2',
    },
  ];

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    requestHandler = handler;

    return createMockApollo([[getSppLinkedGroups, handler]]);
  };

  const createComponent = ({
    propsData = {},
    handler = mockLinkedSppItemsResponse({ groups }),
  } = {}) => {
    wrapper = shallowMountExtended(BlockGroupBranchModification, {
      apolloProvider: createMockApolloProvider(handler),
      provide: {
        assignedPolicyProject: {
          fullPath: 'fullPath',
        },
        namespacePath: 'fullPath',
      },
      propsData: {
        title: 'Best popover',
        enabled: true,
        ...propsData,
      },
      stubs: { GlSprintf },
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findHasExceptionsDropdown = () => wrapper.findComponentByTestId('has-exceptions-selector');
  const findExceptionsDropdown = () => wrapper.findComponentByTestId('exceptions-selector');

  describe('rendering', () => {
    it('renders the default', () => {
      createComponent();
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#in-a-group',
      );
      expect(findHasExceptionsDropdown().exists()).toBe(true);
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });

    it('renders when enabled', () => {
      createComponent({ propsData: { enabled: true } });
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#in-a-group',
      );
      expect(findHasExceptionsDropdown().exists()).toBe(true);
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });

    it('renders when not enabled and without exceptions', () => {
      createComponent({ propsData: { enabled: false } });
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findHasExceptionsDropdown().props('disabled')).toBe(true);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });
  });

  describe('existing exceptions', () => {
    const EXCEPTIONS = [{ id: 1 }, { id: 2 }];

    beforeEach(async () => {
      createComponent({ propsData: { enabled: true, exceptions: EXCEPTIONS } });
      await waitForPromises();
    });

    it('retrieves and displays groups', () => {
      expect(requestHandler).toHaveBeenCalledTimes(1);
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          withCount: false,
          topLevelOnly: true,
          fullPath: 'fullPath',
          includeParentDescendants: false,
        }),
      );
      expect(findExceptionsDropdown().props('items')).toHaveLength(3);
    });

    it('renders the except selection dropdown', () => {
      expect(findHasExceptionsDropdown().props('selected')).toBe(EXCEPT_GROUPS);
    });

    it('renders the group selection dropdown', () => {
      expect(findExceptionsDropdown().exists()).toBe(true);
      expect(findExceptionsDropdown().props('selected')).toEqual([1, 2]);
    });

    it('retrieves exception groups and uses them for the dropdown text', () => {
      expect(findExceptionsDropdown().props('toggleText')).toEqual('fullName1, fullName2');
    });

    it('updates the toggle text on selection', async () => {
      createComponent({
        propsData: { enabled: true, exceptions: EXCEPTIONS },
      });
      await wrapper.setProps({ enabled: true, exceptions: [...EXCEPTIONS, { id: 3 }] });
      await waitForPromises();

      expect(findExceptionsDropdown().props('toggleText')).toEqual('fullName1, fullName2 +1 more');
    });

    it('updates the toggle text on deselection', async () => {
      await wrapper.setProps({ enabled: true, exceptions: [{ id: 2 }] });
      await waitForPromises();
      expect(findExceptionsDropdown().props('toggleText')).toEqual('fullName2');
    });

    it('updates the toggle text when disabled', async () => {
      await wrapper.setProps({ enabled: false });

      expect(findExceptionsDropdown().exists()).toBe(false);
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted()).toEqual({});
    });
  });

  describe('events', () => {
    it('updates the policy when exceptions are added', async () => {
      createComponent({ propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] } });
      await findHasExceptionsDropdown().vm.$emit('select', WITHOUT_EXCEPTIONS);
      expect(wrapper.emitted('change')[0][0]).toEqual(true);
    });

    it('updates the policy when exceptions are changed', async () => {
      createComponent({ propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] } });
      await findExceptionsDropdown().vm.$emit('select', [1]);
      expect(wrapper.emitted('change')[0][0]).toEqual({
        enabled: true,
        exceptions: [{ id: 1 }],
      });
    });

    it('does not update the policy when exceptions are changed and the setting is not enabled', async () => {
      createComponent({ propsData: { enabled: false } });
      await findHasExceptionsDropdown().vm.$emit('select', EXCEPT_GROUPS);
      expect(wrapper.emitted('change')).toEqual(undefined);
    });

    it('filters groups when search is performed', async () => {
      createComponent({ propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] } });
      await waitForPromises();

      const initialItems = findExceptionsDropdown().props('items');
      expect(initialItems).toHaveLength(3);

      await findExceptionsDropdown().vm.$emit('search', 'group1');
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenCalledWith(expect.objectContaining({ search: 'group1' }));
    });
  });

  describe('error', () => {
    it('handles error', async () => {
      createComponent({
        propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] },
        handler: jest.fn().mockRejectedValue({}),
      });
      await waitForPromises();
      expect(findExceptionsDropdown().props('items')).toEqual([]);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch groups',
      });
    });
  });

  describe('exceptions that were not initially loaded', () => {
    it('loads and displays groups from exceptions list', async () => {
      createComponent({
        propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }, { id: 7 }, { id: 8 }] },
        handler: mockLinkedSppItemsResponse({ groups: [createMockGroups(5)] }),
      });
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({
          ids: [
            'gid://gitlab/Group/1',
            'gid://gitlab/Group/2',
            'gid://gitlab/Group/7',
            'gid://gitlab/Group/8',
          ],
        }),
      );

      expect(findExceptionsDropdown().exists()).toBe(true);
      expect(findExceptionsDropdown().props('selected')).toEqual([1, 2, 7, 8]);
    });
  });

  describe('infinite scroll', () => {
    it('does not fetch more groups when there is no next page', async () => {
      createComponent({ propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] } });
      await waitForPromises();
      findExceptionsDropdown().vm.$emit('bottom-reached');

      expect(requestHandler).toHaveBeenCalledTimes(1);
    });

    it('fetches more groups when there is a next page', async () => {
      createComponent({
        propsData: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] },
        handler: mockLinkedSppItemsResponse({
          groups: [createMockGroups()],
          pageInfo: { ...defaultPageInfo, hasNextPage: true },
        }),
      });
      await waitForPromises();
      findExceptionsDropdown().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({
          ids: ['gid://gitlab/Group/1', 'gid://gitlab/Group/2'],
        }),
      );
    });
  });
});
