import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlPopover, GlLink } from '@gitlab/ui';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import getSppLinkedProjectGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import getDescendantGroups from 'ee/security_orchestration/graphql/queries/get_descendant_groups.query.graphql';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockGroups } from 'ee_jest/security_orchestration/mocks/mock_data';

describe('ScopedGroupsDropdown', () => {
  let wrapper;
  let requestHandler;

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
  ];

  const groupsIds = groups.map(({ id }) => id);

  const mapItems = ({ id, name, fullPath }) => ({ text: name, value: id, fullPath });

  const moreGroups = createMockGroups(4);

  const groupsHandler = (nodes = moreGroups) =>
    jest.fn().mockResolvedValue({
      data: {
        groups: {
          count: nodes.length,
          nodes,
          pageInfo: {},
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([
      [getSppLinkedProjectGroups, requestHandler.linkedGroupsHandler],
      [getGroups, requestHandler.groupsHandler],
      [getDescendantGroups, requestHandler.descendantGroupsHandler],
    ]);
  };

  const descendantGroups = [
    {
      id: 'gid://gitlab/Group/10',
      fullName: 'Descendant Group 1',
      fullPath: 'parent/descendant-1',
      avatarUrl: 'avatarUrl10',
    },
    {
      id: 'gid://gitlab/Group/11',
      fullName: 'Descendant Group 2',
      fullPath: 'parent/descendant-2',
      avatarUrl: 'avatarUrl11',
    },
  ];

  const descendantGroupsHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        avatarUrl: null,
        fullName: 'Parent Group',
        fullPath: 'parent',
        descendantGroups: {
          nodes: descendantGroups,
          pageInfo: {
            hasNextPage: false,
            endCursor: null,
          },
        },
      },
    },
  });

  const defaultHandler = {
    linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
    groupsHandler: groupsHandler(),
    descendantGroupsHandler,
  };

  const createComponent = ({
    propsData = {},
    handler = defaultHandler,
    provide = {},
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(ScopedGroupsDropdown, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        fullPath: 'gitlab-org',
        ...propsData,
      },
      stubs,
      provide: { designatedAsCsp: false, ...provide },
    });
  };

  const findDropdown = () => wrapper.findComponent(BaseItemsDropdown);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findFooter = () => wrapper.findComponent(ProjectsCountMessage);

  describe('loading items', () => {
    it('renders loading state', () => {
      createComponent();
      expect(findDropdown().props('loading')).toBe(true);
      expect(findFooter().exists()).toBe(false);
    });

    it('emits error if loading fails', async () => {
      createComponent({
        handler: jest.fn().mockRejectedValue({}),
      });

      await waitForPromises();
      expect(wrapper.emitted('linked-items-query-error')).toHaveLength(1);
      expect(wrapper.emitted('loaded')).toEqual([[[]]]);
    });
  });

  describe('groups', () => {
    it('renders default dropdown state', async () => {
      createComponent();
      await waitForPromises();
      expect(findDropdown().props('headerText')).toBe('Select groups');
      expect(findDropdown().props('itemTypeName')).toBe('groups');
      expect(findDropdown().props('loading')).toBe(false);
    });

    describe('csp group', () => {
      it('renders groups in dropdown', async () => {
        createComponent({
          provide: { designatedAsCsp: true },
          propsData: { withProjectCount: true },
        });
        await waitForPromises();
        expect(findDropdown().props('items')).toEqual(moreGroups.map(mapItems));
        expect(findFooter().exists()).toBe(true);
      });

      it('maintains existing items when fetching more groups', async () => {
        createComponent({
          provide: { designatedAsCsp: true },
          propsData: { withProjectCount: true },
        });
        await waitForPromises();
        expect(findDropdown().props('items')).toHaveLength(moreGroups.length);
        await findDropdown().vm.$emit('bottom-reached');
        await waitForPromises();
        expect(requestHandler.groupsHandler).toHaveBeenCalledTimes(2);
      });

      it('sets allGroupsCount from groups.count', async () => {
        const cspGroupsHandler = jest.fn().mockResolvedValue({
          data: {
            groups: {
              count: 10,
              nodes: moreGroups,
              pageInfo: {},
            },
          },
        });

        createComponent({
          provide: { designatedAsCsp: true },
          propsData: { withProjectCount: true },
          handler: {
            linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
            groupsHandler: cspGroupsHandler,
            descendantGroupsHandler,
          },
        });
        await waitForPromises();

        expect(findFooter().props('totalCount')).toBe(10);
      });
    });

    describe('descendant groups', () => {
      it('fetches descendant groups when useDescendantGroups is true', async () => {
        const linkedGroupsHandler = jest.fn();
        const mockGroupsHandler = jest.fn();
        createComponent({
          propsData: { useDescendantGroups: true },
          handler: {
            linkedGroupsHandler,
            groupsHandler: mockGroupsHandler,
            descendantGroupsHandler,
          },
        });
        await waitForPromises();

        expect(linkedGroupsHandler).not.toHaveBeenCalled();
        expect(mockGroupsHandler).not.toHaveBeenCalled();
        expect(descendantGroupsHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            rootNamespacePath: 'gitlab-org',
            search: '',
          }),
        );
      });

      it('renders descendant groups in dropdown', async () => {
        createComponent({ propsData: { useDescendantGroups: true } });
        await waitForPromises();

        const items = findDropdown().props('items');
        expect(items).toHaveLength(2);
        expect(items).toEqual([
          {
            text: 'Descendant Group 1',
            value: 'gid://gitlab/Group/10',
            fullPath: 'parent/descendant-1',
          },
          {
            text: 'Descendant Group 2',
            value: 'gid://gitlab/Group/11',
            fullPath: 'parent/descendant-2',
          },
        ]);
      });

      it('does not show popover when useDescendantGroups is true and no groups exist', async () => {
        createComponent({
          propsData: { useDescendantGroups: true },
          handler: {
            linkedGroupsHandler: mockLinkedSppItemsResponse({ groups: [] }),
          },
        });
        await waitForPromises();

        expect(findPopover().exists()).toBe(false);
      });

      it('sets allGroupsCount from group.descendantGroups.count', async () => {
        const descendantGroupsHandlerWithCount = jest.fn().mockResolvedValue({
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              avatarUrl: null,
              fullName: 'Parent Group',
              fullPath: 'parent',
              descendantGroups: {
                count: 5,
                nodes: descendantGroups,
                pageInfo: {
                  hasNextPage: false,
                  endCursor: null,
                },
              },
            },
          },
        });

        createComponent({
          propsData: { useDescendantGroups: true, withProjectCount: true },
          handler: {
            linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
            groupsHandler: groupsHandler(),
            descendantGroupsHandler: descendantGroupsHandlerWithCount,
          },
        });
        await waitForPromises();

        expect(findFooter().props('totalCount')).toBe(5);
      });
    });

    describe('linked group', () => {
      it('renders linked groups in dropdown', async () => {
        createComponent();
        await waitForPromises();
        expect(findDropdown().props('items')).toEqual(groups.map(mapItems));
      });

      it('maintains existing items when fetching more groups', async () => {
        createComponent();
        await waitForPromises();
        const initialItems = findDropdown().props('items');
        expect(initialItems).toHaveLength(groups.length);
        await findDropdown().vm.$emit('bottom-reached');
        await waitForPromises();
        expect(requestHandler.linkedGroupsHandler).toHaveBeenCalledTimes(2);
        expect(findDropdown().props('items').length).toBeGreaterThanOrEqual(initialItems.length);
      });

      it('sets allGroupsCount from top-level count plus descendant counts', async () => {
        const groupsWithDescendants = [
          {
            id: '1',
            name: 'group1',
            fullPath: 'fullPath1',
            fullName: 'fullName1',
            avatarUrl: 'avatarUrl1',
            descendantGroups: { count: 2, nodes: [], pageInfo: defaultDescendantPageInfo },
          },
          {
            id: '2',
            name: 'group2',
            fullPath: 'fullPath2',
            fullName: 'fullName2',
            avatarUrl: 'avatarUrl2',
            descendantGroups: { count: 3, nodes: [], pageInfo: defaultDescendantPageInfo },
          },
        ];

        const linkedGroupsHandlerWithCount = jest.fn().mockResolvedValue({
          data: {
            project: {
              __typename: 'Project',
              id: '1',
              securityPolicyProjectLinkedGroups: {
                count: 2,
                nodes: groupsWithDescendants,
                pageInfo: {},
              },
            },
          },
        });

        createComponent({
          propsData: { withProjectCount: true },
          handler: {
            linkedGroupsHandler: linkedGroupsHandlerWithCount,
            groupsHandler: groupsHandler(),
            descendantGroupsHandler,
          },
        });
        await waitForPromises();

        // 2 (top-level) + 2 (group1 descendants) + 3 (group2 descendants) = 7
        expect(findFooter().props('totalCount')).toBe(7);
      });

      describe('descendant pagination', () => {
        const descendantNodes = [
          {
            id: 'gid://gitlab/Group/100',
            name: 'descendant-1',
            fullPath: 'parent/descendant-1',
            fullName: 'descendant-1',
            avatarUrl: 'avatarUrl100',
          },
        ];

        const descendantPageInfoWithNextPage = {
          __typename: 'PageInfo',
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'start-cursor',
          endCursor: 'descendant-end-cursor',
        };

        const parentGroupWithPaginatedDescendants = [
          {
            id: '1',
            name: 'parent-group',
            fullPath: 'parent-group',
            fullName: 'parent-group',
            avatarUrl: 'avatarUrl1',
            descendantGroups: {
              count: 2,
              nodes: descendantNodes,
              pageInfo: descendantPageInfoWithNextPage,
            },
          },
        ];

        it('shows infinite scroll when descendants have more pages', async () => {
          createComponent({
            handler: {
              linkedGroupsHandler: mockLinkedSppItemsResponse({
                groups: parentGroupWithPaginatedDescendants,
              }),
              groupsHandler: groupsHandler(),
              descendantGroupsHandler,
            },
          });
          await waitForPromises();

          expect(findDropdown().props('infiniteScroll')).toBe(true);
        });

        it('fetches more descendants when bottom-reached is emitted', async () => {
          const secondPageDescendant = {
            id: 'gid://gitlab/Group/200',
            name: 'descendant-2',
            fullPath: 'parent/descendant-2',
            fullName: 'descendant-2',
            avatarUrl: 'avatarUrl200',
          };

          const secondPageResponse = [
            {
              ...parentGroupWithPaginatedDescendants[0],
              descendantGroups: {
                count: 2,
                nodes: [secondPageDescendant],
                pageInfo: defaultDescendantPageInfo,
              },
            },
          ];

          const linkedGroupsHandler = jest
            .fn()
            .mockResolvedValueOnce(
              mockLinkedSppItemsResponse({
                groups: parentGroupWithPaginatedDescendants,
              })(),
            )
            .mockResolvedValueOnce(mockLinkedSppItemsResponse({ groups: secondPageResponse })());

          createComponent({
            handler: {
              linkedGroupsHandler,
              groupsHandler: groupsHandler(),
              descendantGroupsHandler,
            },
          });
          await waitForPromises();

          const itemsBefore = findDropdown().props('items');
          expect(itemsBefore).toEqual(
            expect.arrayContaining([expect.objectContaining({ value: descendantNodes[0].id })]),
          );

          await findDropdown().vm.$emit('bottom-reached');
          await waitForPromises();

          expect(linkedGroupsHandler).toHaveBeenCalledTimes(2);
          expect(linkedGroupsHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              afterDescendants: 'descendant-end-cursor',
            }),
          );

          const itemsAfter = findDropdown().props('items');
          expect(itemsAfter).toEqual(
            expect.arrayContaining([
              expect.objectContaining({ value: descendantNodes[0].id }),
              expect.objectContaining({ value: secondPageDescendant.id }),
            ]),
          );
        });

        it('fetches parent pages when descendant pagination is exhausted', async () => {
          const parentGroupNoMoreDescendants = [
            {
              id: '1',
              name: 'parent-group',
              fullPath: 'parent-group',
              fullName: 'parent-group',
              avatarUrl: 'avatarUrl1',
              descendantGroups: {
                count: 1,
                nodes: descendantNodes,
                pageInfo: defaultDescendantPageInfo,
              },
            },
          ];

          const linkedGroupsHandler = jest.fn().mockResolvedValue({
            data: {
              project: {
                __typename: 'Project',
                id: '1',
                securityPolicyProjectLinkedGroups: {
                  nodes: parentGroupNoMoreDescendants,
                  pageInfo: {
                    __typename: 'PageInfo',
                    hasNextPage: true,
                    hasPreviousPage: false,
                    startCursor: 'start',
                    endCursor: 'parent-end-cursor',
                  },
                },
              },
            },
          });

          createComponent({
            handler: {
              linkedGroupsHandler,
              groupsHandler: groupsHandler(),
              descendantGroupsHandler,
            },
          });
          await waitForPromises();

          await findDropdown().vm.$emit('bottom-reached');
          await waitForPromises();

          expect(linkedGroupsHandler).toHaveBeenCalledTimes(2);
          expect(linkedGroupsHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              after: 'parent-end-cursor',
            }),
          );
        });
      });
    });
  });

  describe('selected items', () => {
    it('renders selected items', async () => {
      createComponent({
        propsData: {
          selected: groupsIds,
        },
        stubs: {
          BaseItemsDropdown,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(groupsIds);
      expect(findDropdown().findComponent(GlCollapsibleListbox).props('toggleText')).toEqual(
        'All groups',
      );
    });
  });

  describe('search', () => {
    it.each([groups[0].name, `${groups[0].name}   `])(
      'searches by text and trims spaces',
      async (searchValue) => {
        createComponent();

        await waitForPromises();

        await findDropdown().vm.$emit('search', searchValue);
        expect(findDropdown().props('items')).toEqual([groups[0]].map(mapItems));
      },
    );

    it('searches by fullPath', async () => {
      createComponent();

      await waitForPromises();

      await findDropdown().vm.$emit('search', groups[0].fullPath);
      expect(findDropdown().props('items')).toEqual([groups[0]].map(mapItems));
    });

    it('passes descendantSearch instead of search for linked groups', async () => {
      const linkedGroupsHandler = mockLinkedSppItemsResponse({ groups });

      createComponent({
        handler: {
          linkedGroupsHandler,
          groupsHandler: groupsHandler(),
          descendantGroupsHandler,
        },
      });

      await findDropdown().vm.$emit('search', 'subgroup-name');

      expect(linkedGroupsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          search: '',
          descendantSearch: 'subgroup-name',
          includeParentDescendants: true,
        }),
      );
    });

    it('sets includeParentDescendants to true when searching for linked groups', async () => {
      const linkedGroupsHandler = mockLinkedSppItemsResponse({ groups });

      createComponent({
        handler: {
          linkedGroupsHandler,
          groupsHandler: groupsHandler(),
          descendantGroupsHandler,
        },
      });

      await findDropdown().vm.$emit('search', 'test-search');

      expect(linkedGroupsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          includeParentDescendants: true,
        }),
      );
    });
  });

  describe('popover', () => {
    it('does not render popover when groups exist', async () => {
      createComponent();
      await waitForPromises();

      expect(findPopover().exists()).toBe(false);
      const loadedItems = wrapper.emitted('loaded')[0][0];
      expect(loadedItems).toHaveLength(groups.length);
      expect(loadedItems.map(({ id }) => id)).toEqual(groups.map(({ id }) => id));
    });

    it('does not render popover when there are no groups but loading is in progress', () => {
      createComponent({
        handler: mockLinkedSppItemsResponse({ groups: [] }),
      });

      expect(findPopover().exists()).toBe(false);
      expect(findDropdown().props('disabled')).toBe(false);
    });

    it('renders popover when there are no groups', async () => {
      createComponent({
        handler: mockLinkedSppItemsResponse({ groups: [] }),
      });
      await waitForPromises();

      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('show')).toBe(true);
      expect(findDropdown().props('disabled')).toBe(true);
      expect(findPopover().text()).toContain('No linked groups');
      expect(wrapper.emitted('loaded')).toEqual([[[]]]);
      expect(findPopover().findComponent(GlLink).attributes('href')).toBe(
        '/help/user/application_security/policies/enforcement/security_policy_projects.md',
      );
    });
  });

  describe('include descendants', () => {
    it('includes descendant groups in dropdown items', async () => {
      const groupWithDescendants = [
        {
          id: '1',
          name: 'parent-group',
          fullPath: 'parent-group',
          fullName: 'parent-group',
          avatarUrl: 'avatarUrl1',
          descendantGroups: {
            count: 1,
            pageInfo: defaultDescendantPageInfo,
            nodes: [
              {
                id: '2',
                name: 'child-group',
                fullPath: 'parent-group/child-group',
                fullName: 'child-group',
                avatarUrl: 'avatarUrl2',
                descendantGroups: { count: 0, nodes: [] },
              },
            ],
          },
        },
      ];

      createComponent({
        propsData: {
          includeDescendants: true,
        },
        handler: {
          linkedGroupsHandler: mockLinkedSppItemsResponse({ groups: groupWithDescendants }),
          groupsHandler: groupsHandler(),
        },
      });

      await waitForPromises();

      const items = findDropdown().props('items');
      expect(items).toHaveLength(2);
      expect(items).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ text: 'parent-group' }),
          expect.objectContaining({ text: 'child-group' }),
        ]),
      );
    });
  });

  describe('select items', () => {
    it('selects items and emits selected event', async () => {
      createComponent();
      await waitForPromises();
      findDropdown().vm.$emit('select', [groups[0].id]);

      const selectedItems = wrapper.emitted('select')[0][0];
      expect(selectedItems).toHaveLength(1);
      expect(selectedItems[0]).toEqual(
        expect.objectContaining({ id: groups[0].id, name: groups[0].name }),
      );
    });
  });

  describe('missing groups', () => {
    it('loads and displays groups that were selected but missing from first loaded page', async () => {
      const missingGroup = moreGroups[2];
      const missingGroupId = missingGroup.id.toString();

      createComponent({
        propsData: {
          selected: [groupsIds[0], missingGroupId],
        },
        handler: {
          linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
          groupsHandler: groupsHandler([missingGroup]),
        },
      });
      await waitForPromises();

      const items = findDropdown().props('items');
      const itemIds = items.map(({ value }) => String(value));

      expect(itemIds).toContain(groupsIds[0]);
      expect(itemIds).toContain(missingGroupId);
    });
  });

  describe('default rendering with project count', () => {
    it('renders footer with group count information', async () => {
      createComponent({
        propsData: {
          withProjectCount: true,
        },
        handler: {
          linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
          groupsHandler: groupsHandler(),
          descendantGroupsHandler,
        },
      });
      await waitForPromises();

      expect(findFooter().exists()).toBe(true);
      expect(findFooter().props('infoText')).toBe('groups');
      expect(findDropdown().props('loading')).toBe(false);
    });
  });
});
