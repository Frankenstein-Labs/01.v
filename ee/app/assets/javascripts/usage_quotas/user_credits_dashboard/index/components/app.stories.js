import VueApollo from 'vue-apollo';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { buildMockSelfCreditsUsage } from '../graphql/mock_data';
import UserCreditsDashboardApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/user_credits_dashboard/app',
  component: UserCreditsDashboardApp,
};

export default meta;

// Both queries are resolved client-side by the same local `selfCreditsUsage`
// resolver, so the scenarios are driven by swapping its implementation.
const pending = () => new Promise(() => {});

// Only the filter-scoped query passes `startDate`, so a single resolver can
// serve the dashboard-level and the filter-scoped query different results.
const splitResolver =
  ({ dashboard = buildMockSelfCreditsUsage, filtered = buildMockSelfCreditsUsage }) =>
  (_, args) =>
    args.startDate ? filtered() : dashboard();

const createTemplate = (config = {}) => {
  const { resolver = () => buildMockSelfCreditsUsage() } = config;

  const defaultClient = createMockClient([], { Query: { selfCreditsUsage: resolver } });
  const apolloProvider = new VueApollo({ defaultClient });

  return (args, { argTypes }) => ({
    apolloProvider,
    components: { UserCreditsDashboardApp },
    provide: {
      namespacePath: 'gitlab-org',
      ...config.provide,
    },
    props: Object.keys(argTypes),
    template: `<user-credits-dashboard-app />`,
  });
};

export const Default = {
  render: createTemplate(),
};

export const LoadingState = {
  render: (...args) => createTemplate({ resolver: pending })(...args),
};

// The billing-period card and the filters are resolved while the filter-scoped
// data is still in flight.
export const FilteredUsageLoading = {
  render: (...args) => createTemplate({ resolver: splitResolver({ filtered: pending }) })(...args),
};

export const FilteredUsageError = {
  render: (...args) =>
    createTemplate({
      resolver: splitResolver({
        filtered: () => Promise.reject(new Error('Failed to fetch filtered credit usage data')),
      }),
    })(...args),
};

export const ErrorState = {
  render: (...args) =>
    createTemplate({
      resolver: () => Promise.reject(new Error('Failed to fetch credit usage data')),
    })(...args),
};

export const UsageBillingDisabled = {
  render: (...args) =>
    createTemplate({
      resolver: () => ({ ...buildMockSelfCreditsUsage(), enabled: false }),
    })(...args),
};

export const OutdatedClient = {
  render: (...args) =>
    createTemplate({
      resolver: () => ({ ...buildMockSelfCreditsUsage(), isOutdatedClient: true }),
    })(...args),
};

export const NoUsage = {
  render: (...args) =>
    createTemplate({
      resolver: () => ({
        ...buildMockSelfCreditsUsage(),
        creditsUsed: 0,
        dailyAverage: 0,
        dailyUsage: [],
      }),
    })(...args),
};
