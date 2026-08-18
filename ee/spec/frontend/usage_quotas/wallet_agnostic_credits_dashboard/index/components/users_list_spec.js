import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlKeysetPagination,
  GlSorting,
  GlTable,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsersList from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/users_list.vue';
import { mockSubscriptionCreditsUsageData } from '../../mock_data';

describe('UsersList', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockUsers = mockSubscriptionCreditsUsageData.data.subscriptionUsage.usersUsage.users;
  const mockUserUsagePath = '/test-group/-/usage_quotas/usage_billing/users/__USERNAME__';

  const createComponent = ({
    propsData: {
      users = mockUsers,
      userUsagePath = mockUserUsagePath,
      sortBy = 'totalCreditsUsed',
      sortAscending = false,
    } = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(UsersList, {
      propsData: { users, userUsagePath, sortBy, sortAscending },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findSorting = () => wrapper.findComponent(GlSorting);
  const findRows = () => findTable().find('tbody').findAll('tr');
  const findCell = (rowIndex, cellIndex) => findRows().at(rowIndex).findAll('td').at(cellIndex);
  const findAvatarLabeled = (rowIndex) => findRows().at(rowIndex).findComponent(GlAvatarLabeled);
  const findAvatarLink = (rowIndex) => findRows().at(rowIndex).findComponent(GlAvatarLink);
  const findUsageControlStatusCell = (rowIndex) =>
    findRows().at(rowIndex).find('[data-testid="usage-control-status-cell"]');
  const findBadgeInUsageControlStatusCell = (rowIndex) =>
    findUsageControlStatusCell(rowIndex).findComponent(GlBadge);
  const findAutomatedFlowBadge = (rowIndex) =>
    findRows().at(rowIndex).find('[data-testid="automated-flow-badge"]');

  describe('table rendering', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('renders a row for each user', () => {
      expect(findRows()).toHaveLength(mockUsers.nodes.length);
    });

    it('renders GlAvatarLabeled with user name and username', () => {
      const avatar = findAvatarLabeled(0);

      expect(avatar.props('label')).toBe('Alice Johnson');
      expect(avatar.props('subLabel')).toBe('@ajohnson');
      expect(avatar.props('src')).toBe(mockUsers.nodes[0].avatarUrl);
    });

    it('renders credits used in the second column', () => {
      expect(findCell(0, 1).text()).toBe('1.2k');
    });

    it('links to the user detail page', () => {
      const link = findAvatarLink(0);

      expect(link.attributes('href')).toBe(
        '/test-group/-/usage_quotas/usage_billing/users/ajohnson',
      );
    });

    it('does not render automated flow badge for human users', () => {
      expect(findAutomatedFlowBadge(0).exists()).toBe(false);
    });

    it('renders automated flow badge for non-human users', () => {
      expect(findAutomatedFlowBadge(1).text()).toBe('Automated flow');
    });

    it('does not render automated flow badge for unknown future entity types', () => {
      createComponent({
        propsData: {
          users: {
            ...mockUsers,
            nodes: [{ ...mockUsers.nodes[0], entityType: 'future_entity_type' }],
          },
        },
        mountFn: mountExtended,
      });

      expect(findAutomatedFlowBadge(0).exists()).toBe(false);
    });

    it('renders "Blocked usage" badge for a blocked user', () => {
      const cell = findUsageControlStatusCell(0);
      const badge = findBadgeInUsageControlStatusCell(0);

      expect(cell.exists()).toBe(true);
      expect(badge.props('variant')).toBe('danger');
      expect(badge.text()).toBe('Blocked usage');
    });

    it('renders "Regular usage" badge for a non-blocked user', () => {
      const cell = findUsageControlStatusCell(1);
      const badge = findBadgeInUsageControlStatusCell(1);

      expect(cell.exists()).toBe(true);
      expect(badge.props('variant')).toBe('neutral');
      expect(badge.text()).toBe('Regular usage');
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders pagination with correct props', () => {
      expect(findPagination().props()).toMatchObject({
        hasNextPage: mockUsers.pageInfo.hasNextPage,
        hasPreviousPage: mockUsers.pageInfo.hasPreviousPage,
        startCursor: mockUsers.pageInfo.startCursor,
        endCursor: mockUsers.pageInfo.endCursor,
      });
    });

    it('emits next-page with the cursor on next', async () => {
      findPagination().vm.$emit('next', 'nextCursor');
      await nextTick();

      expect(wrapper.emitted('next-page')).toEqual([['nextCursor']]);
    });

    it('emits prev-page with the cursor on prev', async () => {
      findPagination().vm.$emit('prev', 'prevCursor');
      await nextTick();

      expect(wrapper.emitted('prev-page')).toEqual([['prevCursor']]);
    });
  });

  describe('sorting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlSorting with default sort by totalCreditsUsed descending', () => {
      expect(findSorting().props('sortBy')).toBe('totalCreditsUsed');
      expect(findSorting().props('isAscending')).toBe(false);
    });

    it('emits sort-change with sortBy and sortAscending when sort by changes', async () => {
      findSorting().vm.$emit('sortByChange', 'name');
      await nextTick();

      expect(wrapper.emitted('sort-change')).toEqual([[{ sortBy: 'name', sortAscending: false }]]);
    });

    it('emits sort-change with sortBy and sortAscending when sort direction changes', async () => {
      findSorting().vm.$emit('sortDirectionChange');
      await nextTick();

      expect(wrapper.emitted('sort-change')).toEqual([
        [{ sortBy: 'totalCreditsUsed', sortAscending: true }],
      ]);
    });
  });

  describe('empty state', () => {
    beforeEach(() => {
      createComponent({
        propsData: { users: { nodes: [] } },
        mountFn: mountExtended,
      });
    });

    it('renders the empty state message', () => {
      expect(findTable().text()).toContain('No user data available');
    });
  });
});
