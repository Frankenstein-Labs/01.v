import VueApollo from 'vue-apollo';
import {
  mockUsersUsageDataWithPool,
  mockUsersUsageDataWithoutPool,
  mockUsersUsageDataWithNullUsage,
  usageDataCommitmentWithMonthlyWaiverWithOverage,
  usageDataWithCommitment,
  mockUsageDataBase,
  usageDataNoCommitmentWithOverage,
  usageDataNoCommitmentWithOverageWithOverageNotAllowed,
  usageDataWithCommitmentWithOverage,
  usageDataWithCommitmentWithMonthlyWaiver,
  usageDataWithOutdatedClient,
  usageDataWithDisabledState,
  usageDataOnPaidTierTrial,
} from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getSubscriptionUsersUsageQuery from '../graphql/get_subscription_users_usage.query.graphql';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
import UsageBillingApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/usage_billing/app',
  component: UsageBillingApp,
};

export default meta;

/**
 *
 * @param {Object} config
 * @param {Object} [config.provide]
 * @param {Function} [config.getSubscriptionUsersUsageQueryHandler]
 * @param {Function} [config.getSubscriptionUsageQueryHandler]
 */
const createTemplate = (config = {}) => {
  let { getSubscriptionUsersUsageQueryHandler, getSubscriptionUsageQueryHandler } = config;

  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getSubscriptionUsersUsageQueryHandler) {
      getSubscriptionUsersUsageQueryHandler = () => Promise.resolve(mockUsersUsageDataWithPool);
    }
    if (!getSubscriptionUsageQueryHandler) {
      getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithCommitment);
    }

    const requestHandlers = [
      [getSubscriptionUsersUsageQuery, getSubscriptionUsersUsageQueryHandler],
      [getSubscriptionUsageQuery, getSubscriptionUsageQueryHandler],
    ];
    defaultClient = createMockClient(requestHandlers);
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  window.gon.display_gitlab_credits_user_data = config.display_gitlab_credits_user_data ?? true;

  return (args, { argTypes }) => ({
    apolloProvider,
    components: {
      UsageBillingApp: () => Promise.resolve(UsageBillingApp),
    },
    provide: {
      userUsagePath: '/gitlab_duo/users/__USERNAME__',
    },
    props: Object.keys(argTypes),
    template: `<usage-billing-app />`,
  });
};

export const Default = {
  render: createTemplate(),
};

export const CommitmentWithMonthlyWaiverCredits = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataWithCommitmentWithMonthlyWaiver);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const CommitmentWithMonthlyWaiverWithOverage = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataCommitmentWithMonthlyWaiverWithOverage);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const CommitmentWithOverage = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataWithCommitmentWithOverage);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoCommitmentWithOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataNoCommitmentWithOverage);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoCommitmentWithOverageWithOverageNotAllowed = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataNoCommitmentWithOverageWithOverageNotAllowed);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NoCommitmentNoMonthlyWaiverNoOverage = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithoutPool);

    const getSubscriptionUsageQueryHandler = () => Promise.resolve(mockUsageDataBase);

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const PaidTierTrial = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataOnPaidTierTrial);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const NullValuesTolerance = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithCommitment);

    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.resolve(mockUsersUsageDataWithNullUsage);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const OutdatedClientWarning = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithOutdatedClient);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const DisabledStateWarning = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => Promise.resolve(usageDataWithDisabledState);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
    })(...args);
  },
};

export const LoadingState = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () => new Promise(() => {});
    const getSubscriptionUsersUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getSubscriptionUsageQueryHandler,
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const LoadingUsersUsageState = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getSubscriptionUsageQueryHandler,
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const ErrorUsersUsageState = {
  render: (...args) => {
    const getSubscriptionUsersUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch usage data'));

    return createTemplate({
      getSubscriptionUsersUsageQueryHandler,
    })(...args);
  },
};

export const CommitmentWithDisabledUserDetails = {
  render: (...args) => {
    const getSubscriptionUsageQueryHandler = () =>
      Promise.resolve(usageDataWithCommitmentWithMonthlyWaiver);

    return createTemplate({
      getSubscriptionUsageQueryHandler,
      display_gitlab_credits_user_data: false,
    })(...args);
  },
};
