import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlBadge,
  GlSorting,
  GlTableLite,
  GlProgressBar,
  GlAlert,
  GlKeysetPagination,
  GlEmptyState,
  GlSearchBoxByType,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { merge } from 'lodash-es';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import getSubscriptionUsersUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_subscription_users_usage.query.graphql';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { PAGE_SIZE } from 'ee/usage_quotas/usage_billing/constants';
import {
  mockUsersUsageDataWithPool,
  mockUsersUsageDataWithZeroAllocation,
  mockUsersUsageDataWithNoUsers,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/logger');

describe('UsageByUserTab', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  /** @type {jest.Mock} */
  let getSubscriptionUsersUsageQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended, provide, propsData } = {}) => {
    const defaultClient = createMockClient([
      [getSubscriptionUsersUsageQuery, getSubscriptionUsersUsageQueryHandler],
    ]);

    const apolloProvider = new VueApollo({ defaultClient });

    wrapper = mountFn(UsageByUserTab, {
      apolloProvider,
      propsData: { hasCommitment: true, ...propsData },
      provide: {
        namespacePath: null,
        userUsagePath: '/path/to/user/__USERNAME__',
        ...provide,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRows = () => findTable().find('tbody').findAll('tr');
  const findSorting = () => wrapper.findComponent(GlSorting);
  const findProgressBars = () => wrapper.findAllComponents(GlProgressBar);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const NAME_FIELD = { key: 'name', label: 'User' };
  const INCLUDED_CREDITS_FIELD = { key: 'includedCredits', label: 'Included credits' };
  const TOTAL_CREDITS_FIELD = {
    key: 'totalCreditsUsed',
    label: 'Total credits used',
    tdClass: 'gl-text-right',
    thAlignRight: true,
  };
  const USAGE_CONTROL_FIELD = {
    key: 'usageControlStatus',
    label: 'Usage control status',
    tdAttr: { 'data-testid': 'usage-control-status-cell' },
  };

  beforeEach(() => {
    getSubscriptionUsersUsageQueryHandler = jest.fn();
  });

  describe('normal state', () => {
    beforeEach(() => {
      getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockUsersUsageDataWithPool);
    });

    describe('rendering table', () => {
      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('renders the table with correct props', () => {
        expect(findTable().props('fields')).toEqual([
          NAME_FIELD,
          INCLUDED_CREDITS_FIELD,
          TOTAL_CREDITS_FIELD,
          USAGE_CONTROL_FIELD,
        ]);
      });

      it('renders progress bars with correct values', () => {
        const progressBars = findProgressBars();

        expect(progressBars).toHaveLength(8);

        // testing the first couple of instances
        expect(progressBars.at(0).props('value')).toBe(100);
        expect(progressBars.at(1).props('value')).toBe(100);
        expect(progressBars.at(2).props('value')).toBe(10);
      });

      describe('when no users have creditsUsed or totalCredits', () => {
        beforeEach(async () => {
          getSubscriptionUsersUsageQueryHandler.mockResolvedValue(
            mockUsersUsageDataWithZeroAllocation,
          );

          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('renders the table without included credits column', () => {
          expect(findTable().props('fields')).toEqual([
            NAME_FIELD,
            TOTAL_CREDITS_FIELD,
            USAGE_CONTROL_FIELD,
          ]);

          expect(findProgressBars()).toHaveLength(0);
        });
      });

      it('will render all rows', () => {
        const rows = findRows();
        expect(rows).toHaveLength(8);
      });

      describe.each`
        index | username      | displayName        | includedCreditsUsed | includedCreditsUsedPercent | totalCreditsUsed
        ${0}  | ${'ajohnson'} | ${'Alice Johnson'} | ${'500 / 500'}      | ${100}                     | ${'690.33'}
        ${1}  | ${'bsmith'}   | ${'Bob Smith'}     | ${'500 / 500'}      | ${100}                     | ${'500'}
        ${2}  | ${'cdavis'}   | ${'Carol Davis'}   | ${'50 / 500'}       | ${10}                      | ${'50'}
        ${3}  | ${'dwilson'}  | ${'David Wilson'}  | ${'2k / 2k'}        | ${100}                     | ${'2.1k'}
      `(
        '$index: rendering $displayName ($username)',
        ({
          index,
          username,
          displayName,
          includedCreditsUsed,
          includedCreditsUsedPercent,
          totalCreditsUsed,
        }) => {
          const findRow = () => findRows().at(index);
          const findCell = (cellIndex) => findRow().find(`td:nth-child(${cellIndex})`);

          describe('user cell', () => {
            it('renders user avatar with link to the user details page', () => {
              const userAvatar = findCell(1).findComponent(UserAvatarLink);
              expect(userAvatar.props('linkHref')).toBe(`/path/to/user/${username}`);
            });

            it('renders user name', () => {
              const cell = findCell(1);
              expect(cell.text()).toBe(displayName);
            });
          });

          describe('included credits used cell', () => {
            it('renders the included usage values', () => {
              const cell = findCell(2);
              expect(cell.text()).toBe(includedCreditsUsed);
            });

            it('renders the progress bars for included credits', () => {
              const cell = findCell(2);
              const progressBar = cell.findComponent(GlProgressBar);

              expect(progressBar.props('value')).toBe(includedCreditsUsedPercent);
            });
          });

          it('renders total credits used cell', () => {
            const cell = findCell(3);

            expect(cell.text()).toBe(totalCreditsUsed);
          });
        },
      );

      describe('with paidTierTrialCreditsUsed', () => {
        beforeEach(async () => {
          const mockData = merge({}, mockUsersUsageDataWithPool, {
            data: {
              subscriptionUsage: {
                usersUsage: {
                  users: {
                    nodes: [
                      {
                        usage: {
                          paidTierTrialCreditsUsed: 100,
                        },
                      },
                    ],
                  },
                },
              },
            },
          });
          getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockData);
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('includes paidTierTrialCreditsUsed in total credits used', () => {
          const firstRow = findRows().at(0);
          const totalCreditsCell = firstRow.find('td:nth-child(3)');

          expect(totalCreditsCell.text()).toBe('790.33');
        });
      });

      describe('usage control status column', () => {
        const findBadgesInColumn = () => {
          const rows = findRows();
          return rows.wrappers.map((row) => {
            const cell = row.find('[data-testid="usage-control-status-cell"]');
            return cell.findComponent(GlBadge);
          });
        };

        it('renders blocked badge for blocked users', () => {
          const badges = findBadgesInColumn();

          // Bob Smith (index 1) is blocked
          expect(badges[1].text()).toBe('Blocked usage');
          expect(badges[1].props('variant')).toBe('danger');
        });

        it('renders "Regular usage" badge for non-blocked users', () => {
          const badges = findBadgesInColumn();

          // Henry Brown (index 7) in not blocked
          expect(badges[7].text()).toBe('Regular usage');
          expect(badges[7].props('variant')).toBe('neutral');
        });
      });
    });

    // gitlab:quarantine_issue_url=https://gitlab.com/gitlab-org/gitlab/-/work_items/592966
    // eslint-disable-next-line jest/no-disabled-tests
    describe.skip('search', () => {
      beforeEach(async () => {
        getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockUsersUsageDataWithPool);
        createComponent();
        await waitForPromises();
      });

      it('calls the gql query with the correct `searchQuery`', async () => {
        const searchQuery = 'search';
        findSearchBox().vm.$emit('input', searchQuery);
        await waitForPromises();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledTimes(2);
        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ searchQuery }),
        );
      });

      it('trims `searchQuery` before sending the request', async () => {
        findSearchBox().vm.$emit('input', ' trimmed ');
        await waitForPromises();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledTimes(2);
        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ searchQuery: 'trimmed' }),
        );
      });

      it('does not use a query with less than 3 characters', async () => {
        const searchQuery = ' no ';
        findSearchBox().vm.$emit('input', searchQuery);
        await waitForPromises();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledTimes(1);
        expect(getSubscriptionUsersUsageQueryHandler).not.toHaveBeenCalledWith(
          expect.objectContaining({ searchQuery }),
        );
      });
    });

    describe('pagination', () => {
      const findPagination = () => wrapper.findComponent(GlKeysetPagination);

      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('calls the graphql query on load', () => {
        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: null,
            first: PAGE_SIZE,
            last: null,
            sort: 'TOTAL_CREDITS_USED_DESC',
          }),
        );
      });

      it('will render the pagination', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toEqual(
          expect.objectContaining(
            mockUsersUsageDataWithPool.data.subscriptionUsage.usersUsage.users.pageInfo,
          ),
        );
      });

      it('navigates to next page', async () => {
        getSubscriptionUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('next', '42');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: '42',
            before: null,
            first: PAGE_SIZE,
            last: null,
          }),
        );
      });

      it('navigates to prev page', async () => {
        getSubscriptionUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('prev', '37');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: '37',
            first: null,
            last: PAGE_SIZE,
          }),
        );
      });
    });

    describe('sorting', () => {
      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('shows a message about sorting by credits', () => {
        expect(wrapper.find('header').text()).toContain(
          'Sorting by total credits used displays only users with prior credit usage.',
        );
      });

      it('calls the graphql query with default sort on load', () => {
        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            sort: 'TOTAL_CREDITS_USED_DESC',
          }),
        );
      });

      it('renders GlSorting with correct default props', () => {
        expect(findSorting().props('sortBy')).toBe('totalCreditsUsed');
        expect(findSorting().props('isAscending')).toBe(false);
      });

      it('calls the graphql query with updated sort when sortBy changes', async () => {
        getSubscriptionUsersUsageQueryHandler.mockClear();

        findSorting().vm.$emit('sortByChange', 'name');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            sort: 'NAME_DESC',
            after: null,
            before: null,
            first: PAGE_SIZE,
            last: null,
          }),
        );
      });

      it('updates sort direction when sortDirectionChange is emitted', async () => {
        findSorting().vm.$emit('sortDirectionChange');
        await waitForPromises();

        expect(findSorting().props('isAscending')).toBe(true);
      });

      it('resets pagination when sort changes', async () => {
        findSorting().vm.$emit('sortByChange', 'name');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: null,
            first: PAGE_SIZE,
            last: null,
          }),
        );
      });
    });
  });

  describe('SaaS', () => {
    beforeEach(async () => {
      createComponent({ provide: { namespacePath: 'some_namespace' } });
      await waitForPromises();
    });

    it('passes the namespace path to the API', () => {
      expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          namespacePath: 'some_namespace',
        }),
      );
    });
  });

  describe('loading state', () => {
    beforeEach(async () => {
      getSubscriptionUsersUsageQueryHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('doesnt render the table', () => {
      expect(findTable().exists()).toBe(false);
    });

    it('renders the loading skeleton', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('loading state passed to table', () => {
    it('binds the Apollo loading state to the table busy prop', async () => {
      getSubscriptionUsersUsageQueryHandler.mockResolvedValueOnce(mockUsersUsageDataWithPool);
      createComponent();
      await waitForPromises();

      expect(findTable().vm.$attrs.busy).toBe(wrapper.vm.$apollo.queries.usersUsage.loading);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      getSubscriptionUsersUsageQueryHandler.mockRejectedValue(new Error('Failed to fetch data'));
      createComponent();
      await waitForPromises();
    });

    it('reports the error', () => {
      expect(logError).toHaveBeenCalled();
      expect(captureException).toHaveBeenCalled();
    });

    it('renders alert', () => {
      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockUsersUsageDataWithNoUsers);
      createComponent();
      await waitForPromises();
    });

    it('renders with no description', () => {
      expect(findEmptyState().props().title).toBe('No users found');
      expect(findEmptyState().props().description).toBe('');
    });

    // gitlab:quarantine_issue_url=https://gitlab.com/gitlab-org/gitlab/-/work_items/592966
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('renders with description when showing search results', async () => {
      findSearchBox().vm.$emit('input', 'search');
      await waitForPromises();

      expect(findEmptyState().props().title).toBe('No users found');
      expect(findEmptyState().props().description).toBe('Edit your search and try again.');
    });
  });
});
