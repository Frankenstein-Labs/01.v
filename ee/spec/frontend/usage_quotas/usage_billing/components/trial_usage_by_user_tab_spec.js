import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlProgressBar, GlAlert, GlKeysetPagination } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TrialUsageByUserTab from 'ee/usage_quotas/usage_billing/components/trial_usage_by_user_tab.vue';
import getTrialUsersUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_trial_users_usage.query.graphql';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { mockTrialUsersUsageData, mockTrialUsersUsageDataWithZeroAllocation } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/logger');

describe('TrialUsageByUserTab', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  /** @type {jest.Mock} */
  let getTrialUsersUsageQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended, provide } = {}) => {
    const defaultClient = createMockClient([
      [getTrialUsersUsageQuery, getTrialUsersUsageQueryHandler],
    ]);

    const apolloProvider = new VueApollo({ defaultClient });

    wrapper = mountFn(TrialUsageByUserTab, {
      apolloProvider,
      provide: {
        namespacePath: null,
        ...provide,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findProgressBars = () => wrapper.findAllComponents(GlProgressBar);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    getTrialUsersUsageQueryHandler = jest.fn();
  });

  describe('normal state', () => {
    beforeEach(() => {
      getTrialUsersUsageQueryHandler.mockResolvedValue(mockTrialUsersUsageData);
    });

    describe('rendering table', () => {
      const findRows = () => findTable().find('tbody').findAll('tr');

      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('renders the table with correct props', () => {
        expect(findTable().props('fields')).toEqual([
          {
            key: 'user',
            label: 'User',
          },
          {
            key: 'includedCredits',
            label: 'Included credits',
          },
          {
            key: 'totalCreditsUsed',
            label: 'Total credits used',
            tdClass: 'gl-text-right',
            thAlignRight: true,
          },
        ]);
      });

      describe('rendering table', () => {
        it('will render all rows', () => {
          const rows = findRows();
          expect(rows).toHaveLength(3);
        });

        describe.each`
          index | username      | displayName        | includedCreditsUsed | includedCreditsUsedPercent | totalCreditsUsed
          ${0}  | ${'ajohnson'} | ${'Alice Johnson'} | ${'24 / 24'}        | ${100}                     | ${'24'}
          ${1}  | ${'bsmith'}   | ${'Bob Smith'}     | ${'10 / 24'}        | ${41.66666666666667}       | ${'10'}
          ${2}  | ${'cdavis'}   | ${'Carol Davis'}   | ${'18 / 24'}        | ${75}                      | ${'18'}
        `(
          '$index: rendering $displayName ($username)',
          ({
            index,
            displayName,
            includedCreditsUsed,
            includedCreditsUsedPercent,
            totalCreditsUsed,
          }) => {
            const findRow = () => findRows().at(index);
            const findCell = (cellIndex) => findRow().find(`td:nth-child(${cellIndex})`);

            describe('user cell', () => {
              it('renders user avatar without link', () => {
                const userAvatar = findCell(1).findComponent(UserAvatarLink);
                expect(userAvatar.exists()).toBe(true);
                expect(userAvatar.props('linkHref')).toBe('');
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
      });

      describe('with zero allocation', () => {
        beforeEach(async () => {
          getTrialUsersUsageQueryHandler.mockResolvedValue(
            mockTrialUsersUsageDataWithZeroAllocation,
          );
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('renders the progress bar with 0 value when totalCredits is 0', () => {
          const progressBars = findProgressBars();

          expect(progressBars).toHaveLength(2);
          expect(progressBars.at(0).props('value')).toBe(0);
          expect(progressBars.at(1).props('value')).toBe(0);
        });
      });
    });

    describe('pagination', () => {
      const findPagination = () => wrapper.findComponent(GlKeysetPagination);

      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('calls the graphql query on load', () => {
        expect(getTrialUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: null,
            first: 20,
            last: null,
          }),
        );
      });

      it('will render the pagination', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toMatchObject({
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        });
      });

      it('navigates to next page', async () => {
        getTrialUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('next', '42');
        await nextTick();

        expect(getTrialUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: '42',
            before: null,
            first: 20,
            last: null,
          }),
        );
      });

      it('navigates to prev page', async () => {
        getTrialUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('prev', '37');
        await nextTick();

        expect(getTrialUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: '37',
            first: null,
            last: 20,
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
      expect(getTrialUsersUsageQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          namespacePath: 'some_namespace',
        }),
      );
    });
  });

  describe('loading state', () => {
    beforeEach(async () => {
      getTrialUsersUsageQueryHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('doesnt render the table', () => {
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      getTrialUsersUsageQueryHandler.mockRejectedValue(new Error('Failed to fetch data'));
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
});
