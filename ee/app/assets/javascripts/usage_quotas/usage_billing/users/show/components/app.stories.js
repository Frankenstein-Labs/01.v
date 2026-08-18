import VueApollo from 'vue-apollo';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { typePolicies } from '~/lib/graphql';
import { usageBillingCacheConfig } from 'ee/usage_quotas/usage_billing/apollo_cache_config';
import {
  mockDataWithPool,
  mockDataEvents,
  mockDataWithoutPool,
  mockEmptyData,
  mockEmptyDataEvents,
  mockNullData,
  mockNullDataEvents,
  mockDisabledStateData,
} from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
import getUserSubscriptionUsageQuery from '../graphql/get_user_subscription_usage.query.graphql';
import getUserSubscriptionUsageEventsQuery from '../graphql/get_user_subscription_usage_events.query.graphql';
import UsageBillingUserDashboardApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/usage_billing/users/show/app',
  component: UsageBillingUserDashboardApp,
};

export default meta;

/**
 * @param {Object} config
 * @param {Object} [config.provide]
 * @param {Function} [config.mockHandler]
 */
const createTemplate = (config = {}) => {
  let { getUserSubscriptionUsageQueryHandler, getUserSubscriptionUsageEventsQueryHandler } = config;

  // Apollo
  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getUserSubscriptionUsageQueryHandler) {
      getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockDataWithPool);
    }

    if (!getUserSubscriptionUsageEventsQueryHandler) {
      getUserSubscriptionUsageEventsQueryHandler = () =>
        new Promise((resolve) => {
          setTimeout(() => resolve(mockDataEvents), 300);
        });
    }

    const requestHandlers = [
      [getUserSubscriptionUsageQuery, getUserSubscriptionUsageQueryHandler],
      [getUserSubscriptionUsageEventsQuery, getUserSubscriptionUsageEventsQueryHandler],
    ];
    defaultClient = createMockClient(
      requestHandlers,
      {},
      {
        typePolicies: {
          ...typePolicies,
          ...usageBillingCacheConfig.typePolicies,
        },
      },
    );
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  const { glFeatures = {} } = config;

  return (args, { argTypes }) => ({
    components: {
      UsageBillingUserDashboardApp,
    },
    apolloProvider,
    provide: {
      username: 'john_doe',
      namespacePath: 'gitlab',
      glFeatures,
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-user-dashboard-app />`,
  });
};

export const Default = {
  render: createTemplate(),
};

export const NoCommitment = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockDataWithoutPool);
    const getUserSubscriptionUsageEventsQueryHandler = () => Promise.resolve(mockDataEvents);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
      getUserSubscriptionUsageEventsQueryHandler,
    })(...args);
  },
};

export const EmptyState = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockEmptyData);
    const getUserSubscriptionUsageEventsQueryHandler = () => Promise.resolve(mockEmptyDataEvents);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
      getUserSubscriptionUsageEventsQueryHandler,
    })(...args);
  },
};

export const NullValuesTolerance = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockNullData);
    const getUserSubscriptionUsageEventsQueryHandler = () => Promise.resolve(mockNullDataEvents);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
      getUserSubscriptionUsageEventsQueryHandler,
    })(...args);
  },
};

export const LoadingStateOnListParamsChange = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () =>
      new Promise((resolve) => {
        setTimeout(() => resolve(mockDataWithPool), 1000);
      });

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const DisabledState = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () => Promise.resolve(mockDisabledStateData);

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    // Never resolved
    const getUserSubscriptionUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingStateForEvents = {
  render: (...args) => {
    const getUserSubscriptionUsageEventsQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getUserSubscriptionUsageEventsQueryHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const getUserSubscriptionUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getUserSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const WalletAgnosticUI = {
  render: (...args) => {
    return createTemplate({
      glFeatures: { walletAgnosticCreditsDashboard: true },
    })(...args);
  },
};
