import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import UserCreditsDashboardApp from 'ee/usage_quotas/user_credits_dashboard/index/components/app.vue';
import TotalUsageCard from 'ee/usage_quotas/user_credits_dashboard/index/components/total_usage_card.vue';
import UsageStatisticsCards from 'ee/usage_quotas/user_credits_dashboard/index/components/usage_statistics_cards.vue';
import { buildMockSelfCreditsUsage } from 'ee/usage_quotas/user_credits_dashboard/index/graphql/mock_data';
import ProductsDropdownFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/products_dropdown_filter.vue';
import {
  LAST_MONTH,
  THIS_MONTH,
  TODAY,
} from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/constants';
import DateRangeFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/date_range_filter.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';
import { captureException } from '~/sentry/sentry_browser_wrapper';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('UserCreditsDashboardApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const namespacePath = 'my-group';
  const pending = () => new Promise(() => {});

  // Both queries are resolved client-side by the same local `selfCreditsUsage`
  // resolver. Only the filter-scoped query passes `startDate`, so a single
  // resolver can serve each query a different result.
  const createResolver = ({ dashboard, filtered } = {}) => {
    const dashboardResult = dashboard ?? (() => buildMockSelfCreditsUsage());
    const filteredResult = filtered ?? (() => buildMockSelfCreditsUsage());

    return jest.fn((_, args) => (args.startDate ? filteredResult(args) : dashboardResult(args)));
  };

  const createComponent = ({ resolver } = {}) => {
    const selfCreditsUsage = resolver || createResolver();
    const resolvers = { Query: { selfCreditsUsage } };
    const apolloProvider = createMockApollo([], resolvers);

    wrapper = shallowMountExtended(UserCreditsDashboardApp, {
      apolloProvider,
      provide: { namespacePath },
      stubs: { GlSprintf },
    });

    return selfCreditsUsage;
  };

  const findLoadingIndicator = () => wrapper.findByTestId('skeleton-loader');
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findDisabledAlert = () => wrapper.findByTestId('usage-billing-disabled-alert');
  const findOutdatedClientAlert = () => wrapper.findByTestId('outdated-client-alert');
  const findDashboard = () => wrapper.findByTestId('user-credits-dashboard');
  const findTotalUsageCard = () => wrapper.findComponent(TotalUsageCard);
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findProductsDropdownFilter = () => wrapper.findComponent(ProductsDropdownFilter);
  const findFilteredLoadingIndicator = () => wrapper.findByTestId('filtered-usage-skeleton-loader');
  const findFilteredErrorAlert = () => wrapper.findByTestId('filtered-usage-error-alert');
  const findUsageStatisticsCards = () => wrapper.findComponent(UsageStatisticsCards);

  describe('while the dashboard query is loading', () => {
    let resolver;

    beforeEach(() => {
      resolver = createResolver({ dashboard: pending, filtered: pending });
      createComponent({ resolver });
    });

    it('shows the loading indicator', () => {
      expect(findLoadingIndicator().exists()).toBe(true);
    });

    it('queries the current billing period and the selected range with the namespace path', () => {
      // One call for the billing-period query, one for the filtered query.
      expect(resolver).toHaveBeenCalledTimes(2);
      expect(resolver).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ namespacePath }),
        expect.anything(),
        expect.anything(),
      );
    });

    it('does not render the dashboard, the total usage card, or the filters', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findTotalUsageCard().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findProductsDropdownFilter().exists()).toBe(false);
    });
  });

  describe('while only the filter-scoped query is loading', () => {
    const mockUsage = buildMockSelfCreditsUsage();

    beforeEach(async () => {
      createComponent({
        resolver: createResolver({ dashboard: () => mockUsage, filtered: pending }),
      });
      await waitForPromises();
    });

    it('renders the total usage card and the filters', () => {
      expect(findTotalUsageCard().props()).toMatchObject({
        creditsUsed: mockUsage.creditsUsed,
        startDate: mockUsage.startDate,
        endDate: mockUsage.endDate,
      });
      expect(findDateRangeFilter().exists()).toBe(true);
      expect(findProductsDropdownFilter().exists()).toBe(true);
    });

    it('shows the filtered usage skeleton instead of the dashboard one', () => {
      expect(findFilteredLoadingIndicator().exists()).toBe(true);
      expect(findLoadingIndicator().exists()).toBe(false);
    });

    it('marks the products dropdown as loading', () => {
      expect(findProductsDropdownFilter().props('loading')).toBe(true);
    });
  });

  describe('when data loads successfully', () => {
    const mockUsage = {
      ...buildMockSelfCreditsUsage(),
      creditsUsed: 25,
      dailyAverage: 5,
      dailyUsage: [
        { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-01', creditsUsed: 2 },
        { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-02', creditsUsed: 9 },
        { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-03', creditsUsed: 4 },
      ],
    };

    beforeEach(async () => {
      createComponent({
        resolver: createResolver({ dashboard: () => mockUsage, filtered: () => mockUsage }),
      });
      await waitForPromises();
    });

    it('renders the dashboard container', () => {
      expect(findDashboard().exists()).toBe(true);
    });

    it('renders the total usage card with the billing-period values', () => {
      expect(findTotalUsageCard().props()).toMatchObject({
        creditsUsed: mockUsage.creditsUsed,
        startDate: mockUsage.startDate,
        endDate: mockUsage.endDate,
      });
    });

    it('renders the usage statistics cards with the range-scoped values and peak day', () => {
      expect(findUsageStatisticsCards().props()).toMatchObject({
        totalUsedCredits: 25,
        dailyAverage: 5,
        peakDayUsage: 9,
        peakDayDate: '2026-07-02',
      });
    });

    it('does not show the loading, error, or disabled states', () => {
      expect(findLoadingIndicator().exists()).toBe(false);
      expect(findFilteredLoadingIndicator().exists()).toBe(false);
      expect(findErrorAlert().exists()).toBe(false);
      expect(findFilteredErrorAlert().exists()).toBe(false);
      expect(findDisabledAlert().exists()).toBe(false);
    });

    it('does not show the outdated client alert', () => {
      expect(findOutdatedClientAlert().exists()).toBe(false);
    });

    it('renders the date range and product filters', () => {
      expect(findDateRangeFilter().exists()).toBe(true);
      expect(findProductsDropdownFilter().exists()).toBe(true);
    });

    it('defaults the date range to the current month', () => {
      expect(findDateRangeFilter().props('value')).toEqual(THIS_MONTH);
    });

    // Jest pins the process to GMT (jest.config.base.js), so this locks the
    // derivation rather than reproducing the drift a local start-of-day causes
    // at negative UTC offsets.
    it('caps the custom range at the current UTC date', () => {
      expect(findDateRangeFilter().props('customDateRangeMaxDate')).toEqual(
        newDate(toISODateFormat(TODAY, true)),
      );
    });

    it('builds the products dropdown from the fetched products', () => {
      expect(findProductsDropdownFilter().props('products')).toEqual([
        {
          text: 'GitLab Duo Agent Platform',
          options: [
            { value: 'chat', text: 'Chat' },
            { value: 'code_suggestions', text: 'Code Suggestions' },
          ],
        },
      ]);
    });
  });

  describe('when a filter changes', () => {
    const mockUsage = buildMockSelfCreditsUsage();
    let resolver;

    beforeEach(async () => {
      // The refetch stays in flight so the loading state is deterministic.
      const filtered = jest.fn().mockReturnValueOnce(mockUsage).mockImplementation(pending);

      resolver = createResolver({ dashboard: () => mockUsage, filtered });
      createComponent({ resolver });
      await waitForPromises();
      resolver.mockClear();
    });

    it('refetches the filtered query when the date range changes', async () => {
      findDateRangeFilter().vm.$emit('input', LAST_MONTH);
      await waitForPromises();

      expect(resolver).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          startDate: LAST_MONTH.startDate,
          endDate: LAST_MONTH.endDate,
        }),
        expect.anything(),
        expect.anything(),
      );
    });

    it('refetches the filtered query when the product filter changes', async () => {
      findProductsDropdownFilter().vm.$emit('select', ['chat']);
      await waitForPromises();

      expect(resolver).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ flowTypes: ['chat'] }),
        expect.anything(),
        expect.anything(),
      );
    });

    it('does not refetch the billing-period query', async () => {
      findDateRangeFilter().vm.$emit('input', LAST_MONTH);
      await waitForPromises();

      expect(resolver).not.toHaveBeenCalledWith(
        expect.anything(),
        { namespacePath },
        expect.anything(),
        expect.anything(),
      );
    });

    it('keeps the filters mounted and the total usage card intact while refetching', async () => {
      findDateRangeFilter().vm.$emit('input', LAST_MONTH);
      await waitForPromises();
      await nextTick();

      expect(findDateRangeFilter().exists()).toBe(true);
      expect(findProductsDropdownFilter().exists()).toBe(true);
      expect(findProductsDropdownFilter().props('loading')).toBe(true);
      expect(findTotalUsageCard().props()).toMatchObject({
        creditsUsed: mockUsage.creditsUsed,
        startDate: mockUsage.startDate,
        endDate: mockUsage.endDate,
      });
      expect(findLoadingIndicator().exists()).toBe(false);
      expect(findFilteredLoadingIndicator().exists()).toBe(true);
    });
  });

  describe('when the filter-scoped query errors', () => {
    beforeEach(async () => {
      createComponent({
        resolver: createResolver({
          filtered: () => Promise.reject(new Error('failure')),
        }),
      });
      await waitForPromises();
    });

    it('shows the filtered usage error alert', () => {
      expect(findFilteredErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('keeps the total usage card and the filters visible', () => {
      expect(findDashboard().exists()).toBe(true);
      expect(findTotalUsageCard().exists()).toBe(true);
      expect(findDateRangeFilter().exists()).toBe(true);
      expect(findProductsDropdownFilter().exists()).toBe(true);
    });

    it('logs the error and reports it to Sentry', () => {
      expect(logError).toHaveBeenCalled();
      expect(captureException).toHaveBeenCalled();
    });

    it('clears the error once a filter change resolves', async () => {
      const filtered = jest
        .fn()
        .mockRejectedValueOnce(new Error('failure'))
        .mockImplementation(() => buildMockSelfCreditsUsage());

      createComponent({ resolver: createResolver({ filtered }) });
      await waitForPromises();
      expect(findFilteredErrorAlert().exists()).toBe(true);

      findDateRangeFilter().vm.$emit('input', LAST_MONTH);
      await waitForPromises();

      expect(findFilteredErrorAlert().exists()).toBe(false);
    });
  });

  describe('when the dashboard query errors', () => {
    beforeEach(async () => {
      createComponent({
        resolver: createResolver({
          dashboard: () => Promise.reject(new Error('failure')),
        }),
      });
      await waitForPromises();
    });

    it('shows the error alert', () => {
      expect(findErrorAlert().exists()).toBe(true);
    });

    it('does not render the dashboard, the total usage card, or the filters', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findTotalUsageCard().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findProductsDropdownFilter().exists()).toBe(false);
    });

    it('logs the error and reports it to Sentry', () => {
      expect(logError).toHaveBeenCalled();
      expect(captureException).toHaveBeenCalled();
    });

    it('clears the error once the query is refetched successfully', async () => {
      const dashboard = jest
        .fn()
        .mockRejectedValueOnce(new Error('failure'))
        .mockImplementation(() => buildMockSelfCreditsUsage());

      createComponent({ resolver: createResolver({ dashboard }) });
      await waitForPromises();
      expect(findErrorAlert().exists()).toBe(true);

      wrapper.vm.$apollo.queries.billingPeriodUsage.refetch();
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(false);
      expect(findDashboard().exists()).toBe(true);
    });
  });

  // `enabled` and `isOutdatedClient` describe the dashboard itself, so they are
  // read from the unfiltered query only. A filter selection must not be able to
  // toggle either alert.
  describe('when usage billing is disabled', () => {
    const disabled = () => ({ ...buildMockSelfCreditsUsage(), enabled: false });

    describe('according to the dashboard query', () => {
      beforeEach(async () => {
        createComponent({ resolver: createResolver({ dashboard: disabled }) });
        await waitForPromises();
      });

      it('shows the disabled alert', () => {
        expect(findDisabledAlert().exists()).toBe(true);
      });

      it('does not render the dashboard, the total usage card, or the filters', () => {
        expect(findDashboard().exists()).toBe(false);
        expect(findTotalUsageCard().exists()).toBe(false);
        expect(findDateRangeFilter().exists()).toBe(false);
        expect(findProductsDropdownFilter().exists()).toBe(false);
      });
    });

    describe('according to the filter-scoped query only', () => {
      beforeEach(async () => {
        createComponent({ resolver: createResolver({ filtered: disabled }) });
        await waitForPromises();
      });

      it('renders the dashboard without the disabled alert', () => {
        expect(findDisabledAlert().exists()).toBe(false);
        expect(findDashboard().exists()).toBe(true);
      });
    });
  });

  describe('when the client is outdated', () => {
    const outdated = () => ({ ...buildMockSelfCreditsUsage(), isOutdatedClient: true });

    it('renders the outdated client alert when the dashboard query says so', async () => {
      createComponent({ resolver: createResolver({ dashboard: outdated }) });
      await waitForPromises();

      expect(findDashboard().exists()).toBe(true);
      expect(findOutdatedClientAlert().exists()).toBe(true);
    });

    it('ignores the flag on the filter-scoped query', async () => {
      createComponent({ resolver: createResolver({ filtered: outdated }) });
      await waitForPromises();

      expect(findOutdatedClientAlert().exists()).toBe(false);
    });
  });
});
