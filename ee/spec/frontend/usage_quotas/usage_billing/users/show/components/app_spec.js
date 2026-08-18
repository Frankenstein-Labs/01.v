import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlKeysetPagination, GlAlert, GlAvatar, GlLoadingIcon } from '@gitlab/ui';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';
import EventsTable from 'ee/usage_quotas/usage_billing/users/show/components/events_table.vue';
import FlowTypeFilter from 'ee/usage_quotas/usage_billing/users/show/components/flow_type_filter.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getUserSubscriptionUsageQuery from 'ee/usage_quotas/usage_billing/users/show/graphql/get_user_subscription_usage.query.graphql';
import getUserSubscriptionUsageEventsQuery from 'ee/usage_quotas/usage_billing/users/show/graphql/get_user_subscription_usage_events.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  mockDataWithPool,
  mockDataEvents,
  mockDataWithoutPool,
  mockDisabledStateData,
  mockDataWithPaidTierTrialCredits,
} from '../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const PAGE_SIZE = 20;

describe('UsageBillingUserDashboardApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  /** @type { MockAdapter } */

  const MOCK_USER = mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0];
  const MOCK_USER_EVENTS = mockDataEvents.data.subscriptionUsage.usersUsage.users.nodes[0].events;
  const USERNAME = MOCK_USER.username;

  /** @type {jest.Mock} */
  let mockQueryHandler;
  /** @type {jest.Mock} */
  let mockEventsQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended, glFeatures = {} } = {}) => {
    wrapper = mountFn(UsageBillingUserDashboardApp, {
      apolloProvider: createMockApollo([
        [getUserSubscriptionUsageQuery, mockQueryHandler],
        [getUserSubscriptionUsageEventsQuery, mockEventsQueryHandler],
      ]),
      provide: {
        username: USERNAME,
        namespacePath: null,
        glFeatures,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUserAvatar = () => wrapper.findComponent(GlAvatar);
  const findIncludedCreditsCard = () => wrapper.findByTestId('included-credits-card');
  const findTotalUsageCard = () => wrapper.findByTestId('total-usage-card');
  const findEventsTable = () => wrapper.findComponent(EventsTable);
  const findFlowTypeFilter = () => wrapper.findComponent(FlowTypeFilter);
  const findDisabledStateAlert = () => wrapper.findByTestId('usage-billing-disabled-alert');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findEventsSection = () => wrapper.findByTestId('usage-billing-user-events-list');

  beforeEach(() => {
    window.gon = {
      display_gitlab_credits_user_data: true,
      subscriptions_url: 'https://customers.gitlab.com/',
    };
  });

  beforeEach(() => {
    mockQueryHandler = jest.fn();
    mockEventsQueryHandler = jest.fn();
  });

  describe('loading state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockImplementation(() => new Promise(() => {}));
      mockEventsQueryHandler.mockImplementation(() => new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('shows only a loading icon when fetching data', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('loaded state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockResolvedValue(mockDataWithPool);
      mockEventsQueryHandler.mockResolvedValue(mockDataEvents);
      createComponent();
      await waitForPromises();
    });

    it('calls the subscription usage API with username', () => {
      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          username: USERNAME,
        }),
      );
    });

    it('calls the events API with pagination and filter variables', () => {
      expect(mockEventsQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          username: USERNAME,
          first: PAGE_SIZE,
          last: null,
          after: null,
          before: null,
        }),
      );
    });

    describe('header', () => {
      it('renders user avatar', () => {
        expect(findUserAvatar().exists()).toBe(true);
        expect(findUserAvatar().props('src')).toBe(MOCK_USER.avatarUrl);
      });

      it('renders user info', () => {
        expect(wrapper.text()).toContain(MOCK_USER.name);
        expect(wrapper.text()).toContain(`@${USERNAME}`);
      });
    });

    describe('usage cards', () => {
      it('renders included credits card with correct values', () => {
        const card = findIncludedCreditsCard();

        expect(card.exists()).toBe(true);
        expect(card.text()).toMatchInterpolatedText(`1k / 1k included credits used this month`);
      });

      it('total usage card renders the wallet sum of credits used', () => {
        const card = findTotalUsageCard();

        expect(card.exists()).toBe(true);
        expect(card.text()).toContain(`1.8k`);
      });

      describe('when walletAgnosticCreditsDashboard feature flag is enabled', () => {
        beforeEach(async () => {
          mockQueryHandler.mockResolvedValue(mockDataWithPool);
          mockEventsQueryHandler.mockResolvedValue(mockDataEvents);
          createComponent({ glFeatures: { walletAgnosticCreditsDashboard: true } });
          await waitForPromises();
        });

        it('hides the included credits card', () => {
          expect(findIncludedCreditsCard().exists()).toBe(false);
        });

        it('renders the backend-provided total credits used value', () => {
          const card = findTotalUsageCard();

          expect(card.exists()).toBe(true);
          expect(card.text()).toContain(`10k`);
        });
      });

      describe('when walletAgnosticCreditsDashboard feature flag is disabled', () => {
        beforeEach(async () => {
          mockQueryHandler.mockResolvedValue(mockDataWithPool);
          mockEventsQueryHandler.mockResolvedValue(mockDataEvents);
          createComponent({ glFeatures: { walletAgnosticCreditsDashboard: false } });
          await waitForPromises();
        });

        it('renders the included credits card', () => {
          expect(findIncludedCreditsCard().exists()).toBe(true);
        });

        it('renders the wallet sum of credits used in the total usage card', () => {
          const card = findTotalUsageCard();

          expect(card.exists()).toBe(true);
          expect(card.text()).toContain(`1.8k`);
        });
      });
    });

    describe('events', () => {
      it('renders the events table', () => {
        const eventsTable = findEventsTable();

        expect(eventsTable.exists()).toBe(true);
        expect(eventsTable.props('events')).toStrictEqual(MOCK_USER_EVENTS.nodes);
      });

      describe('filters', () => {
        describe('flow type filtering', () => {
          const ALL_FLOW_TYPES = [
            'ai_catalog_agent',
            'ai_gateway_proxy_use',
            'amazon_q_integration',
            'analytics_agent',
            'chat',
            'code_review',
            'code_suggestions',
            'convert_to_gl_ci',
            'dap_feature_legacy',
            'developer',
            'duo_chat_classic',
            'duo_planner',
            'fix_pipeline',
            'issue_to_merge_request',
            'other_ai_usage',
            'resolve_sast_vulnerability',
            'sast_fp_detection',
            'secrets_fp_detection',
            'security_analyst_agent',
            'software_development',
          ];

          beforeEach(async () => {
            createComponent({ mountFn: mountExtended });
            await waitForPromises();
          });

          it('renders the flow type filter with all used flow types selected', () => {
            const flowTypeFilter = findFlowTypeFilter();

            expect(flowTypeFilter.exists()).toBe(true);
            expect(flowTypeFilter.props('appliedFlowTypes')).toEqual(ALL_FLOW_TYPES);
          });

          it('calls the graphql query with no flowTypes selected on initial load', () => {
            expect(mockEventsQueryHandler).toHaveBeenCalledWith(
              expect.objectContaining({
                flowTypes: null,
              }),
            );
          });

          it('updates the graphql query when flow types are applied', async () => {
            mockEventsQueryHandler.mockClear();

            findFlowTypeFilter().vm.$emit('apply', ['software_development', 'code_review']);
            await nextTick();

            expect(mockEventsQueryHandler).toHaveBeenCalledWith({
              namespacePath: null,
              username: 'alice_johnson',
              flowTypes: ['software_development', 'code_review'],
              first: PAGE_SIZE,
              after: null,
              before: null,
              last: null,
            });
          });

          it("won't fetch events the second time, when all items are selected again", async () => {
            // Preselect some flow types
            findFlowTypeFilter().vm.$emit('apply', ['software_development', 'code_review']);
            await nextTick();

            mockEventsQueryHandler.mockClear();

            findFlowTypeFilter().vm.$emit('apply', ALL_FLOW_TYPES);
            await nextTick();

            expect(mockEventsQueryHandler).not.toHaveBeenCalled();
          });

          it('resets pagination when applying flow type filter', async () => {
            // First navigate to next page
            mockEventsQueryHandler.mockClear();
            findPagination().vm.$emit('next', '42');
            await nextTick();

            expect(mockEventsQueryHandler).toHaveBeenCalledWith(
              expect.objectContaining({
                after: '42',
              }),
            );

            await waitForPromises();

            // Then apply filter
            mockEventsQueryHandler.mockClear();
            findFlowTypeFilter().vm.$emit('apply', ['software_development']);
            await nextTick();

            // Should reset pagination to first page
            expect(mockEventsQueryHandler).toHaveBeenCalledWith(
              expect.objectContaining({
                flowTypes: ['software_development'],
                first: PAGE_SIZE,
                after: null,
                before: null,
                last: null,
              }),
            );
          });

          it('passes flow types from user data to filter component', () => {
            const flowTypeFilter = findFlowTypeFilter();
            const expectedFlowTypes = MOCK_USER.usedFlowTypes.map((flowType) => ({
              value: flowType.id,
              text: flowType.title,
            }));

            expect(flowTypeFilter.props('flowTypes')).toEqual(expectedFlowTypes);
          });
        });
      });

      describe('pagination', () => {
        beforeEach(async () => {
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('calls the events query on load with pagination variables', () => {
          expect(mockEventsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              username: USERNAME,
              after: null,
              before: null,
              first: PAGE_SIZE,
              last: null,
            }),
          );
        });

        it('will render the pagination', () => {
          const { hasNextPage, hasPreviousPage, startCursor, endCursor } =
            MOCK_USER_EVENTS.pageInfo;

          expect(findPagination().exists()).toBe(true);
          expect(findPagination().props()).toEqual(
            expect.objectContaining({
              hasNextPage,
              hasPreviousPage,
              startCursor,
              endCursor,
            }),
          );
        });

        it('calls the events query on next page navigation', async () => {
          mockEventsQueryHandler.mockClear();

          findPagination().vm.$emit('next', '42');
          await nextTick();

          expect(mockEventsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: '42',
              before: null,
              first: PAGE_SIZE,
              last: null,
            }),
          );
        });

        it('calls the events query on prev page navigation', async () => {
          mockEventsQueryHandler.mockClear();

          findPagination().vm.$emit('prev', '37');
          await nextTick();

          expect(mockEventsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: null,
              before: '37',
              first: null,
              last: PAGE_SIZE,
            }),
          );
        });
      });

      describe('events loading state', () => {
        beforeEach(async () => {
          mockQueryHandler.mockResolvedValue(mockDataWithPool);
          mockEventsQueryHandler.mockImplementation(() => new Promise(() => {}));
          createComponent({ mountFn: mountExtended });
          await nextTick();
        });

        it('shows loading icon when events are being fetched', () => {
          const eventsSection = findEventsSection();
          const loadingIcon = eventsSection.findComponent(GlLoadingIcon);

          expect(loadingIcon.exists()).toBe(true);
        });

        it('does not show events table while loading', () => {
          const eventsSection = findEventsSection();
          const eventsTable = eventsSection.findComponent(EventsTable);

          expect(eventsTable.exists()).toBe(false);
        });

        it('does not show pagination while loading', () => {
          const eventsSection = findEventsSection();
          const pagination = eventsSection.findComponent(GlKeysetPagination);

          expect(pagination.exists()).toBe(false);
        });
      });

      describe('events error state', () => {
        beforeEach(async () => {
          mockQueryHandler.mockResolvedValue(mockDataWithPool);
          mockEventsQueryHandler.mockRejectedValue(new Error('Failed to fetch events'));
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('shows error alert when events query fails', () => {
          const eventsSection = findEventsSection();
          const alert = eventsSection.findComponent(GlAlert);

          expect(alert.exists()).toBe(true);
          expect(alert.text()).toBe('An error occurred while fetching events list');
        });

        it('does not show events table on error', () => {
          const eventsSection = findEventsSection();
          const eventsTable = eventsSection.findComponent(EventsTable);

          expect(eventsTable.exists()).toBe(false);
        });

        it('does not show pagination on error', () => {
          const eventsSection = findEventsSection();
          const pagination = eventsSection.findComponent(GlKeysetPagination);

          expect(pagination.exists()).toBe(false);
        });

        it('logs the error to console and Sentry', () => {
          expect(logError).toHaveBeenCalledWith(expect.any(Error));
          expect(captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  });

  describe('when user has paidTierTrialCreditsUsed', () => {
    beforeEach(() => {
      mockQueryHandler.mockResolvedValue(mockDataWithPaidTierTrialCredits);
      mockEventsQueryHandler.mockResolvedValue(mockDataWithPaidTierTrialCredits);
    });

    it('includes paidTierTrialCreditsUsed in the wallet sum when feature flag is disabled', async () => {
      createComponent();
      await waitForPromises();

      const card = findTotalUsageCard();

      expect(card.exists()).toBe(true);
      expect(card.text()).toContain('2.1k');
    });

    it('renders the backend-provided total credits used value when feature flag is enabled', async () => {
      createComponent({ glFeatures: { walletAgnosticCreditsDashboard: true } });
      await waitForPromises();

      const card = findTotalUsageCard();

      expect(card.exists()).toBe(true);
      expect(card.text()).toContain('8.9k');
    });
  });

  describe('disabled state alert', () => {
    describe('when Usage Billing is available', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockDataWithoutPool);
        mockEventsQueryHandler.mockResolvedValue(mockDataEvents);
        createComponent();
        await waitForPromises();
      });

      it('does not render alert if enabled is true', () => {
        expect(findDisabledStateAlert().exists()).toBe(false);
      });

      it('displays all other elements', () => {
        expect(wrapper.findByTestId('usage-billing-user-header').exists()).toBe(true);
        expect(wrapper.findByTestId('usage-billing-user-cards-row').exists()).toBe(true);
        expect(wrapper.findByTestId('usage-billing-user-events-list').exists()).toBe(true);
      });
    });

    describe('when Usage Billing is disabled', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockDisabledStateData);
        mockEventsQueryHandler.mockResolvedValue(mockDisabledStateData);
        createComponent();
        await waitForPromises();
      });

      it('renders disabled state alert', () => {
        expect(findDisabledStateAlert().exists()).toBe(true);
      });

      it('hides all other components', () => {
        expect(wrapper.findByTestId('usage-billing-user-header').exists()).toBe(false);
        expect(wrapper.findByTestId('usage-billing-user-cards-row').exists()).toBe(false);
        expect(wrapper.findByTestId('usage-billing-user-events-list').exists()).toBe(false);
      });
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      mockQueryHandler.mockRejectedValue(new Error('Network Error'));
      mockEventsQueryHandler.mockRejectedValue(new Error('Network Error'));
      createComponent();
      await waitForPromises();
    });

    it('shows error alert when API request fails', () => {
      const alert = findAlert();
      expect(alert.text()).toBe('An error occurred while fetching usage data');
    });

    it('logs the error to console and Sentry', () => {
      expect(logError).toHaveBeenCalledWith(expect.any(Error));
      expect(captureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });
});
