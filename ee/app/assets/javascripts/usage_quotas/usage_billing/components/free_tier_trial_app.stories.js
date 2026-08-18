import VueApollo from 'vue-apollo';
import {
  mockTrialUsageDataWithActiveTrial,
  mockTrialUsersUsageData,
} from 'ee_jest/usage_quotas/usage_billing/free_tier_trial_mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getTrialUsageQuery from '../graphql/get_trial_usage.query.graphql';
import getTrialUsersUsageQuery from '../graphql/get_trial_users_usage.query.graphql';
import FreeTierTrialApp from './free_tier_trial_app.vue';

const meta = {
  title: 'ee/usage_quotas/usage_billing/free_tier_trial_app',
  component: FreeTierTrialApp,
};

export default meta;

/**
 * @param {Object} config
 * @param {Function} [config.getTrialUsageQueryHandler]
 * @param {Function} [config.getTrialUsersUsageQueryHandler]
 */
const createTemplate = (config = {}) => {
  let { getTrialUsageQueryHandler, getTrialUsersUsageQueryHandler } = config;

  let defaultClient = config.apollo?.defaultClient;
  if (!defaultClient) {
    if (!getTrialUsageQueryHandler) {
      getTrialUsageQueryHandler = () => Promise.resolve(mockTrialUsageDataWithActiveTrial);
    }

    if (!getTrialUsersUsageQueryHandler) {
      getTrialUsersUsageQueryHandler = () => Promise.resolve(mockTrialUsersUsageData);
    }

    const requestHandlers = [
      [getTrialUsageQuery, getTrialUsageQueryHandler],
      [getTrialUsersUsageQuery, getTrialUsersUsageQueryHandler],
    ];
    defaultClient = createMockClient(requestHandlers);
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  // preserve original gon to restore it when the component is destroyed
  const originalGon = window.gon;

  return (args, { argTypes }) => ({
    apolloProvider,
    components: {
      FreeTierTrialApp: () => Promise.resolve(FreeTierTrialApp),
    },
    provide: {
      namespacePath: 'my-group',
      isFree: true,
    },
    props: Object.keys(argTypes),
    template: `<free-tier-trial-app />`,
    mounted: () => {
      window.gon = {
        ...originalGon,
        display_gitlab_credits_user_data: config.display_gitlab_credits_user_data ?? true,
      };
    },
    beforeDestroy: () => {
      window.gon = originalGon;
    },
  });
};

export const Default = {
  render: createTemplate(),
};

export const LoadingState = {
  render: (...args) => {
    const getTrialUsageQueryHandler = () => new Promise(() => {});

    return createTemplate({
      getTrialUsageQueryHandler,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const getTrialUsageQueryHandler = () =>
      Promise.reject(new Error('Failed to fetch trial usage data'));

    return createTemplate({
      getTrialUsageQueryHandler,
    })(...args);
  },
};

export const UserDataDisabled = {
  render: (...args) => {
    const getTrialUsageQueryHandler = () => Promise.resolve(mockTrialUsageDataWithActiveTrial);

    return createTemplate({
      getTrialUsageQueryHandler,
      display_gitlab_credits_user_data: false,
    })(...args);
  },
};
