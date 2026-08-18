import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlSprintf, GlTab } from '@gitlab/ui';
import GitlabCreditsDashboardApp from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/app.vue';
import CreditsConsumptionChart from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/credits_consumption_chart.vue';
import DateRangeFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/date_range_filter.vue';
import subscriptionCreditsUsageQuery from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/graphql/get_subscription_credits_usage_overview.query.graphql';
import {
  THIS_MONTH,
  LAST_MONTH,
  LAST_7_DAYS,
  LAST_30_DAYS,
  CUSTOM,
} from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import UsageCards from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/usage_cards.vue';
import ProductsDropdownFilter from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/products_dropdown_filter.vue';
import ProductsList from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/products_list.vue';
import UsersList from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/users_list.vue';
import { mockSubscriptionCreditsUsageData } from '../../mock_data';

const DATE_RANGE_OPTIONS = [THIS_MONTH, LAST_MONTH, LAST_7_DAYS, LAST_30_DAYS, CUSTOM];

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('WalletAgnosticCreditsDashboard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  /** @type { jest.Mock} */
  let subscriptionCreditsUsageHandler;

  const createComponent = ({ provide = {}, handler } = {}) => {
    const requestHandler = handler || subscriptionCreditsUsageHandler;

    const apolloProvider = createMockApollo([[subscriptionCreditsUsageQuery, requestHandler]]);

    wrapper = shallowMountExtended(GitlabCreditsDashboardApp, {
      apolloProvider,
      provide: {
        userUsagePath: '/test-group/-/usage_quotas/usage_billing/users/__USERNAME__',
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findOutdatedClientAlert = () => wrapper.findByTestId('outdated-client-alert');
  const findUsageBillingDisabledAlert = () =>
    wrapper.findComponentByTestId('usage-billing-disabled-alert');
  const findUsageScopeAlert = () => wrapper.findByTestId('usage-scope-copy');
  const findLoadingIndicator = () => wrapper.findByTestId('skeleton-loaders');
  const findTabs = () => wrapper.findAllComponents(GlTab);
  const findProductsList = () => wrapper.findComponent(ProductsList);
  const findUsersList = () => wrapper.findComponent(UsersList);
  const findCreditsConsumptionChart = () => wrapper.findComponent(CreditsConsumptionChart);
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findProductsDropdownFilter = () => wrapper.findComponent(ProductsDropdownFilter);
  const findUserDataDisabledMessage = () => wrapper.findByTestId('user-data-disabled-message');

  beforeEach(() => {
    subscriptionCreditsUsageHandler = jest.fn().mockResolvedValue(mockSubscriptionCreditsUsageData);
    window.gon = { display_gitlab_credits_user_data: true };
  });

  describe('loading state', () => {
    beforeEach(async () => {
      subscriptionCreditsUsageHandler = jest.fn().mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('shows loading state when fetching data', () => {
      expect(findLoadingIndicator().exists()).toBe(true);
    });

    it('calls the apollo query', () => {
      expect(subscriptionCreditsUsageHandler).toHaveBeenCalledTimes(1);
    });

    it('passes loading prop to products dropdown filter', () => {
      expect(findProductsDropdownFilter().props('loading')).toBe(true);
    });
  });

  describe('rendering elements', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the heading', () => {
      expect(wrapper.find('h1').text()).toBe('GitLab Credits Overview');
    });

    it('does not show the error alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('shows the usage scope info alert', () => {
      expect(findUsageScopeAlert().text()).toMatchInterpolatedText(
        'This dashboard displays usage of all GitLab Duo Agent Platform features, including non-billable beta and experiment features. For billable usage only, view the dashboard in Customers Portal.',
      );
    });

    it('does not show loading state after data is loaded', () => {
      expect(findLoadingIndicator().exists()).toBe(false);
    });

    it('renders the UsageCards component', () => {
      expect(wrapper.findComponent(UsageCards).props()).toEqual({
        activeUsersCount: 215,
        dailyAverage: 616,
        peakDayDate: '2026-02-17',
        peakDayUsage: 980,
        totalUsedCredits: 13800,
      });
    });

    it('renders the Usage by user tab first', () => {
      expect(findTabs().at(0).attributes('title')).toBe('Usage by user');
    });

    it('renders the Usage by product tab second', () => {
      expect(findTabs().at(1).attributes('title')).toBe('Usage by product');
    });

    it('renders UsersList with users data', () => {
      expect(findUsersList().props('users')).toEqual(
        mockSubscriptionCreditsUsageData.data.subscriptionUsage.usersUsage.users,
      );
    });

    it('renders ProductsList with products data', () => {
      expect(findProductsList().props('products')).toEqual(
        mockSubscriptionCreditsUsageData.data.subscriptionUsage.products,
      );
    });

    it('renders ProductsList with totalUsedCredits', () => {
      expect(findProductsList().props('totalUsedCredits')).toBe(
        mockSubscriptionCreditsUsageData.data.subscriptionUsage.creditsUsed,
      );
    });

    it('does not show the user data disabled message', () => {
      expect(findUserDataDisabledMessage().exists()).toBe(false);
    });
  });

  describe('user data visibility', () => {
    describe('when gon.display_gitlab_credits_user_data is true', () => {
      beforeEach(async () => {
        window.gon = { display_gitlab_credits_user_data: true };
        createComponent();
        await waitForPromises();
      });

      it('renders the UsersList component', () => {
        expect(findUsersList().exists()).toBe(true);
      });

      it('does not show the user data disabled message', () => {
        expect(findUserDataDisabledMessage().exists()).toBe(false);
      });
    });

    describe('when gon.display_gitlab_credits_user_data is false', () => {
      beforeEach(async () => {
        window.gon = { display_gitlab_credits_user_data: false };
        createComponent();
        await waitForPromises();
      });

      it('does not render the UsersList component', () => {
        expect(findUsersList().exists()).toBe(false);
      });

      it('shows the user data disabled message', () => {
        expect(findUserDataDisabledMessage().exists()).toBe(true);
      });

      it('renders a help link in the disabled message', () => {
        expect(findUserDataDisabledMessage().findComponent(GlLink).exists()).toBe(true);
      });
    });
  });

  describe('when dailyUsage is empty', () => {
    beforeEach(async () => {
      subscriptionCreditsUsageHandler = jest.fn().mockResolvedValue({
        data: {
          subscriptionUsage: {
            ...mockSubscriptionCreditsUsageData.data.subscriptionUsage,
            dailyUsage: [],
          },
        },
      });
      createComponent();
      await waitForPromises();
    });

    it('renders UsageCards with zeroed peak day values', () => {
      expect(wrapper.findComponent(UsageCards).props()).toMatchObject({
        peakDayUsage: 0,
        peakDayDate: '',
      });
    });
  });

  describe('group dashboard', () => {
    beforeEach(async () => {
      createComponent({ provide: { namespacePath: 'test-namespace' } });
      await waitForPromises();
    });

    it('passes namespacePath to the query', () => {
      expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          namespacePath: 'test-namespace',
        }),
      );
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      subscriptionCreditsUsageHandler = jest
        .fn()
        .mockRejectedValue(new Error('Failed to fetch data'));
      createComponent();
      await waitForPromises();
    });

    it('logs the error to console and Sentry', () => {
      expect(logError).toHaveBeenCalledWith(expect.any(Error));
      expect(captureException).toHaveBeenCalledWith(expect.any(Error));
    });

    it('shows an error alert', () => {
      expect(findErrorAlert().exists()).toBe(true);
    });

    it('does not show the loading indicator', () => {
      expect(findLoadingIndicator().exists()).toBe(false);
    });
  });

  describe('usage billing disabled state', () => {
    beforeEach(async () => {
      subscriptionCreditsUsageHandler = jest.fn().mockResolvedValue({
        data: {
          subscriptionUsage: {
            ...mockSubscriptionCreditsUsageData.data.subscriptionUsage,
            enabled: false,
          },
        },
      });
      createComponent();
      await waitForPromises();
    });

    it('shows the disabled alert', () => {
      expect(findUsageBillingDisabledAlert().exists()).toBe(true);
    });

    it('does not show the loading indicator', () => {
      expect(findLoadingIndicator().exists()).toBe(false);
    });

    it('does not show the error alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('does not show the main content', () => {
      expect(wrapper.findComponent(UsageCards).exists()).toBe(false);
    });

    it('renders the disabled alert as non-dismissible', () => {
      expect(findUsageBillingDisabledAlert().props('dismissible')).toBe(false);
    });
  });

  describe('outdated client state', () => {
    beforeEach(async () => {
      subscriptionCreditsUsageHandler = jest.fn().mockResolvedValue({
        data: {
          subscriptionUsage: {
            ...mockSubscriptionCreditsUsageData.data.subscriptionUsage,
            isOutdatedClient: true,
          },
        },
      });
      window.gon = {
        display_gitlab_credits_user_data: true,
        subscriptions_url: 'https://customers.gitlab.com',
      };
      createComponent();
      await waitForPromises();
    });

    it('shows the outdated client alert', () => {
      expect(findOutdatedClientAlert().exists()).toBe(true);
    });

    it('renders main content alongside the alert', () => {
      expect(wrapper.findComponent(UsageCards).exists()).toBe(true);
    });

    it('does not show the error alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('links to the subscriptions URL in the outdated client alert', () => {
      expect(findOutdatedClientAlert().findComponent(GlLink).attributes('href')).toBe(
        'https://customers.gitlab.com',
      );
    });
  });

  describe('when isOutdatedClient is false', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show the outdated client alert', () => {
      expect(findOutdatedClientAlert().exists()).toBe(false);
    });
  });

  describe('users sorting', () => {
    it('queries with default sort on mount', async () => {
      createComponent();
      await waitForPromises();

      expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
        expect.objectContaining({ usersListSort: 'TOTAL_CREDITS_USED_DESC' }),
      );
    });

    describe('after initial load', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
        subscriptionCreditsUsageHandler.mockClear();
      });

      it('refetches with new sort key when UsersList emits sort-change', async () => {
        findUsersList().vm.$emit('sort-change', { sortBy: 'name', sortAscending: false });
        await waitForPromises();

        expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
          expect.objectContaining({ usersListSort: 'NAME_DESC' }),
        );
      });

      it('refetches with ascending sort key when UsersList emits sort-change ascending', async () => {
        findUsersList().vm.$emit('sort-change', {
          sortBy: 'totalCreditsUsed',
          sortAscending: true,
        });
        await waitForPromises();

        expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
          expect.objectContaining({ usersListSort: 'TOTAL_CREDITS_USED_ASC' }),
        );
      });

      it('resets pagination when sort changes', async () => {
        findUsersList().vm.$emit('next-page', 'usersEndCursor');
        await waitForPromises();
        subscriptionCreditsUsageHandler.mockClear();

        findUsersList().vm.$emit('sort-change', { sortBy: 'name', sortAscending: false });
        await waitForPromises();

        expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            usersListFirst: 20,
            usersListAfter: null,
            usersListBefore: null,
            usersListLast: null,
          }),
        );
      });
    });
  });

  describe('users pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      subscriptionCreditsUsageHandler.mockClear();
    });

    it('refetches when UsersList emits next-page', async () => {
      findUsersList().vm.$emit('next-page', 'usersEndCursor');
      await waitForPromises();

      expect(subscriptionCreditsUsageHandler).toHaveBeenCalled();
    });

    it('refetches when UsersList emits prev-page', async () => {
      findUsersList().vm.$emit('prev-page', 'usersStartCursor');
      await waitForPromises();

      expect(subscriptionCreditsUsageHandler).toHaveBeenCalled();
    });
  });

  describe('ProductsDropdownFilter', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the ProductsDropdownFilter', () => {
      expect(findProductsDropdownFilter().exists()).toBe(true);
    });

    it('passes products transformed into grouped dropdown items', () => {
      expect(findProductsDropdownFilter().props('products')).toEqual([
        {
          options: [{ text: 'Code Suggestions', value: 'code_suggestions' }],
          text: 'Code Review Summary',
        },
      ]);
    });

    it('is rendered while loading', async () => {
      subscriptionCreditsUsageHandler = jest.fn().mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();

      expect(findProductsDropdownFilter().exists()).toBe(true);
    });

    it('is rendered when there is an error', async () => {
      subscriptionCreditsUsageHandler = jest
        .fn()
        .mockRejectedValue(new Error('Failed to fetch data'));
      createComponent();
      await waitForPromises();

      expect(findProductsDropdownFilter().exists()).toBe(true);
    });
  });

  describe('flowTypes filtering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('queries with empty flowTypes by default', () => {
      expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
        expect.objectContaining({ flowTypes: [] }),
      );
    });

    it('refetches with selected flowTypes when ProductsDropdownFilter emits select', async () => {
      subscriptionCreditsUsageHandler.mockClear();

      findProductsDropdownFilter().vm.$emit('select', ['code_suggestions', 'duo_chat']);
      await waitForPromises();

      expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
        expect.objectContaining({ flowTypes: ['code_suggestions', 'duo_chat'] }),
      );
    });
  });

  describe('CreditsConsumptionChart', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes the correct props to CreditsConsumptionChart', () => {
      expect(findCreditsConsumptionChart().props('dailyUsage')).toEqual(
        mockSubscriptionCreditsUsageData.data.subscriptionUsage.dailyUsage,
      );
      expect(findCreditsConsumptionChart().props('totalCredits')).toEqual(13800);
    });
  });

  describe('DateRangeFilter', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the DateRangeFilter', () => {
      expect(findDateRangeFilter().exists()).toBe(true);
    });

    it('passes all DATE_RANGE_OPTIONS to the filter', () => {
      expect(findDateRangeFilter().props('options')).toEqual(DATE_RANGE_OPTIONS);
    });

    it('passes customDateRangeLimit to the filter', () => {
      expect(findDateRangeFilter().props('customDateRangeLimit')).toBe(366);
    });

    it('passes a UTC Date as customDateRangeMaxDate', () => {
      const maxDate = findDateRangeFilter().props('customDateRangeMaxDate');
      expect(maxDate.toISOString()).toBe('2020-07-06T00:00:00.000Z');
    });

    it('initialises with the first DATE_RANGE_OPTIONS entry selected', () => {
      expect(findDateRangeFilter().props('value')).toMatchObject(DATE_RANGE_OPTIONS[0]);
    });

    describe('when date range changes to a preset', () => {
      it('refetches with the new startDate and endDate', async () => {
        const newRange = DATE_RANGE_OPTIONS[1];
        subscriptionCreditsUsageHandler.mockClear();

        findDateRangeFilter().vm.$emit('input', {
          value: newRange.value,
          startDate: newRange.startDate,
          endDate: newRange.endDate,
        });
        await waitForPromises();

        expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            startDate: newRange.startDate,
            endDate: newRange.endDate,
          }),
        );
      });

      it('passes updated dates to CreditsConsumptionChart', async () => {
        const newRange = DATE_RANGE_OPTIONS[2];

        findDateRangeFilter().vm.$emit('input', {
          value: newRange.value,
          startDate: newRange.startDate,
          endDate: newRange.endDate,
        });
        await waitForPromises();

        expect(findCreditsConsumptionChart().props('startDate')).toBe(newRange.startDate);
        expect(findCreditsConsumptionChart().props('endDate')).toBe(newRange.endDate);
      });
    });

    describe('when custom date range is fully set', () => {
      it('refetches with custom startDate and endDate', async () => {
        subscriptionCreditsUsageHandler.mockClear();

        findDateRangeFilter().vm.$emit('input', {
          value: CUSTOM.value,
          startDate: '2026-01-01',
          endDate: '2026-01-31',
        });
        await waitForPromises();

        expect(subscriptionCreditsUsageHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            startDate: '2026-01-01',
            endDate: '2026-01-31',
          }),
        );
      });
    });
  });

  describe('error clearing', () => {
    it('clears the error when a new date range is selected', async () => {
      subscriptionCreditsUsageHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('Failed'))
        .mockResolvedValue(mockSubscriptionCreditsUsageData);

      createComponent();
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);

      findDateRangeFilter().vm.$emit('input', {
        value: DATE_RANGE_OPTIONS[1].value,
        startDate: DATE_RANGE_OPTIONS[1].startDate,
        endDate: DATE_RANGE_OPTIONS[1].endDate,
      });
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(false);
    });
  });
});
