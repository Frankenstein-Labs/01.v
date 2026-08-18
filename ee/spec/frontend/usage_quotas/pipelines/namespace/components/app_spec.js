import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/namespace/components/minutes_usage_per_month.vue';
import MonthlyUnitsUsageSummary from 'ee/usage_quotas/pipelines/namespace/components/cards/monthly_units_usage_summary.vue';
import AdditionalUnitsUsageSummary from 'ee/usage_quotas/pipelines/namespace/components/cards/additional_units_usage_summary.vue';
import getCiMinutesMonthlySummary from 'ee/usage_quotas/pipelines/namespace/graphql/queries/namespace_ci_minutes_usage.query.graphql';
import getCiMinutesMonthSummaryWithProjects from 'ee/usage_quotas/pipelines/namespace/graphql/queries/projects_ci_minutes_usage.query.graphql';
import PipelineUsageApp from 'ee/usage_quotas/pipelines/namespace/components/app.vue';
import ProjectList from 'ee/usage_quotas/pipelines/namespace/components/project_list.vue';
import {
  LABEL_BUY_ADDITIONAL_MINUTES,
  ERROR_MESSAGE,
} from 'ee/usage_quotas/pipelines/namespace/constants';
import { pushEECproductAddToCartEvent } from 'ee/google_tag_manager';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import {
  defaultProvide,
  mockGetNamespaceCiMinutesUsage,
  mockGetProjectsCiMinutesUsage,
  emptyMockGetCiMinutesUsageNamespaceProjects,
  defaultProjectListProps,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('ee/google_tag_manager');
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/logger');

describe('PipelineUsageApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findDescription = () => wrapper.findByTestId('pipelines-description');
  const findDisabledStateAlert = () =>
    wrapper.findComponentByTestId('instance-runners-disabled-alert');
  const findErrorAlert = () => wrapper.findComponentByTestId('error-alert');
  const findProjectList = () => wrapper.findComponent(ProjectList);
  const findBuyAdditionalMinutesButton = () => wrapper.findComponent(GlButton);
  const findMonthlyUsageOverview = () => wrapper.findComponent(MonthlyUnitsUsageSummary);
  const findPurchasedUsageOverview = () => wrapper.findComponent(AdditionalUnitsUsageSummary);
  const findYearDropdown = () => wrapper.findComponentByTestId('minutes-usage-year-dropdown');
  const findMonthDropdown = () => wrapper.findComponentByTestId('minutes-usage-month-dropdown');
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  const ciMinutesHandler = jest.fn();
  const ciMinutesProjectsHandler = jest.fn();
  const gqlRejectResponse = new Error('GraphQL error');

  const defaultApolloData = {
    subscription: {
      canAddSeats: false,
      canRenew: false,
    },
    userActionAccess: { limitedAccessReason: 'MANAGED_BY_RESELLER' },
  };

  const queryHandlerMock = (apolloData) => jest.fn().mockResolvedValue({ data: apolloData });

  const mockGitlabClient = () => {
    const requestHandlers = [
      [getCiMinutesMonthlySummary, ciMinutesHandler],
      [getCiMinutesMonthSummaryWithProjects, ciMinutesProjectsHandler],
    ];

    return createMockClient(requestHandlers);
  };

  const mockCustomersDotClient = (apolloData) => {
    const requestHandlers = [[getSubscriptionPermissionsData, queryHandlerMock(apolloData)]];

    return createMockClient(requestHandlers);
  };

  const mockApollo = (apolloData) => {
    return new VueApollo({
      defaultClient: mockGitlabClient(),
      clients: {
        customersDotClient: mockCustomersDotClient(apolloData),
        gitlabClient: mockGitlabClient,
      },
    });
  };

  const createComponent = ({ provide = {}, apolloData = defaultApolloData } = {}) => {
    wrapper = shallowMountExtended(PipelineUsageApp, {
      apolloProvider: mockApollo(apolloData),
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        GlButton,
      },
    });
  };

  beforeEach(() => {
    ciMinutesHandler.mockResolvedValue(mockGetNamespaceCiMinutesUsage);
    ciMinutesProjectsHandler.mockResolvedValue(mockGetProjectsCiMinutesUsage);
  });

  describe('rendering', () => {
    it('renders an alert if instance runners are disabled', () => {
      createComponent({ provide: { ciMinutesAnyProjectEnabled: false } });

      const alert = findDisabledStateAlert();
      expect(alert.exists()).toBe(true);
    });

    it('renders description with a help link', () => {
      createComponent();

      expect(findDescription().text()).toContain(
        'Compute minutes usage displays the hosted runner usage against the total available compute minutes.',
      );

      expect(findDescription().findComponent(HelpPageLink).attributes()).toMatchObject({
        anchor: 'compute-usage-calculation',
        href: 'ci/pipelines/compute_minutes',
      });
    });
  });

  describe('Buy additional compute minutes Button', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('calls pushEECproductAddToCartEvent on click', () => {
      findBuyAdditionalMinutesButton().vm.$emit('click');
      expect(pushEECproductAddToCartEvent).toHaveBeenCalledTimes(1);
    });

    it('renders purchase button with the correct attributes', () => {
      expect(findBuyAdditionalMinutesButton().attributes()).toMatchObject({
        href: 'http://test.host/-/subscriptions/buy_minutes?selected_group=12345&ref_source=group_usage_quotas_page',
        target: '_self',
      });
    });

    it('does not show modal on purchase button click', () => {
      findBuyAdditionalMinutesButton().vm.$emit('click');

      expect(findLimitedAccessModal().exists()).toBe(false);
    });

    describe('Gitlab SaaS: valid data for buyAdditionalMinutesPath and buyAdditionalMinutesTarget', () => {
      it('renders the button to buy additional compute minutes', async () => {
        createComponent();

        await waitForPromises();

        expect(findBuyAdditionalMinutesButton().exists()).toBe(true);
        expect(findBuyAdditionalMinutesButton().text()).toBe(LABEL_BUY_ADDITIONAL_MINUTES);
      });
    });

    describe('Gitlab Self-Managed: buyAdditionalMinutesPath and buyAdditionalMinutesTarget not provided', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            buyAdditionalMinutesPath: undefined,
            buyAdditionalMinutesTarget: undefined,
          },
        });
      });

      it('does not render the button to buy additional compute minutes', () => {
        expect(findBuyAdditionalMinutesButton().exists()).toBe(false);
      });
    });
  });

  describe('namespace ci usage overview', () => {
    it('passes correct props to compute minutes UsageOverview', async () => {
      createComponent();

      await waitForPromises();

      expect(findMonthlyUsageOverview().props()).toMatchObject({
        monthlyUnitsUsed: defaultProvide.ciMinutesMonthlyMinutesUsed,
        monthlyUnitsLimit: defaultProvide.ciMinutesMonthlyMinutesLimit,
        monthlyUnitsUsedPercentage: defaultProvide.ciMinutesMonthlyMinutesUsedPercentage,
        lastResetDate: defaultProvide.ciMinutesLastResetDate,
        anyProjectEnabled: defaultProvide.ciMinutesAnyProjectEnabled,
        displayMinutesAvailableData: defaultProvide.ciMinutesDisplayMinutesAvailableData,
      });
    });

    it('passes correct props to purchased compute minutes UsageOverview', async () => {
      createComponent();

      await waitForPromises();

      expect(findPurchasedUsageOverview().props()).toMatchObject({
        additionalUnitsUsed: defaultProvide.ciMinutesPurchasedMinutesUsed,
        additionalUnitsLimit: defaultProvide.ciMinutesPurchasedMinutesLimit,
        additionalUnitsUsedPercentage: defaultProvide.ciMinutesPurchasedMinutesUsedPercentage,
      });
    });

    it.each`
      displayData | purchasedLimit | showAdditionalMinutes
      ${true}     | ${'100'}       | ${true}
      ${true}     | ${'0'}         | ${false}
      ${false}    | ${'100'}       | ${false}
      ${false}    | ${'0'}         | ${false}
    `(
      'shows additional minutes: $showAdditionalMinutes when displayData is $displayData and purchase limit is $purchasedLimit',
      async ({ displayData, purchasedLimit, showAdditionalMinutes }) => {
        createComponent({
          provide: {
            ciMinutesDisplayMinutesAvailableData: displayData,
            ciMinutesPurchasedMinutesLimit: purchasedLimit,
          },
        });
        await waitForPromises();
        expect(findPurchasedUsageOverview().exists()).toBe(showAdditionalMinutes);
      },
    );
  });

  describe('with apollo fetching successful', () => {
    it('passes the correct props to ProjectList', async () => {
      createComponent();

      await waitForPromises();

      expect(findProjectList().props()).toMatchObject(defaultProjectListProps);
    });
  });

  describe('with apollo loading', () => {
    beforeEach(() => {
      ciMinutesHandler.mockReturnValue(new Promise(() => {}));
      ciMinutesProjectsHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
    });

    it('passes loading property to minutes-usaage-per-month component', () => {
      expect(wrapper.findComponent(MinutesUsagePerMonth).props().isLoading).toBe(true);
    });
  });

  describe('with apollo fetching error', () => {
    beforeEach(() => {
      ciMinutesHandler.mockRejectedValue(gqlRejectResponse);
      ciMinutesProjectsHandler.mockRejectedValue(gqlRejectResponse);
      createComponent();
      return waitForPromises();
    });

    it('logs the error message', () => {
      expect(logError).toHaveBeenCalledTimes(3);
      expect(logError).toHaveBeenCalledWith(expect.any(String), gqlRejectResponse);
    });

    it('renders failed request error message', () => {
      expect(findErrorAlert().text()).toBe(ERROR_MESSAGE);
    });

    it('captures the exception in Sentry', async () => {
      await Vue.nextTick();
      expect(captureException).toHaveBeenCalledTimes(3);
    });
  });

  describe('with a namespace without projects', () => {
    beforeEach(() => {
      ciMinutesProjectsHandler.mockResolvedValue(emptyMockGetCiMinutesUsageNamespaceProjects);
      createComponent();
      return waitForPromises();
    });

    it('passes an empty array as projects to ProjectList', () => {
      expect(findProjectList().props('projects')).toEqual([]);
    });
  });

  describe.each`
    pageType          | isUserNamespace | namespaceGQLId
    ${'Namespace'}    | ${false}        | ${convertToGraphQLId(TYPENAME_GROUP, defaultProvide.namespaceId)}
    ${'User profile'} | ${true}         | ${null}
  `('$pageType page type apollo calls', ({ isUserNamespace, namespaceGQLId }) => {
    const defaultPerMonthQueryVariables = {
      date: defaultProvide.ciMinutesLastResetDate,
      first: defaultProvide.pageSize,
      namespaceId: namespaceGQLId,
    };

    beforeEach(async () => {
      createComponent({ provide: { userNamespace: isUserNamespace } });
      await waitForPromises();
    });

    it('sets initial values of Year and Month dropdowns', () => {
      const lastResetDate = new Date(defaultProvide.ciMinutesLastResetDate);
      const expectedYear = lastResetDate.getUTCFullYear().toString();
      const expectedMonth = lastResetDate.getUTCMonth();

      expect(findYearDropdown().props('selected')).toBe(Number(expectedYear));
      expect(findMonthDropdown().props('selected')).toBe(expectedMonth);
    });

    it('makes monthly initial summary call', () => {
      expect(ciMinutesHandler).toHaveBeenCalledTimes(1);
      expect(ciMinutesHandler).toHaveBeenCalledWith({ namespaceId: namespaceGQLId });
    });

    it('makes month projects initial call', () => {
      expect(ciMinutesProjectsHandler).toHaveBeenCalledTimes(1);
      expect(ciMinutesProjectsHandler).toHaveBeenCalledWith({
        ...defaultPerMonthQueryVariables,
        date: defaultProvide.ciMinutesLastResetDate,
      });
    });

    describe('subsequent calls', () => {
      beforeEach(() => {
        ciMinutesHandler.mockClear();
        ciMinutesProjectsHandler.mockClear();
      });

      it('makes a query to fetch more data when `fetch-more` is emitted', async () => {
        findProjectList().vm.$emit('fetch-more', { after: '123' });
        await nextTick();

        expect(ciMinutesHandler).toHaveBeenCalledTimes(0);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledTimes(1);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledWith({
          after: '123',
          ...defaultPerMonthQueryVariables,
        });
      });

      it('will switch years', async () => {
        const selectedItem = {
          text: '2021',
          value: 2021,
        };

        findYearDropdown().vm.$emit('select', selectedItem.value);
        await nextTick();
        expect(findYearDropdown().props('selected')).toBe(selectedItem.value);
        expect(ciMinutesHandler).toHaveBeenCalledTimes(0);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledTimes(1);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledWith({
          ...defaultPerMonthQueryVariables,
          date: '2021-08-01',
        });
      });

      it('will switch months', async () => {
        const selectedItem = {
          text: 'March',
          value: 2,
        };

        findMonthDropdown().vm.$emit('select', selectedItem.value);
        await nextTick();
        expect(findMonthDropdown().props('selected')).toBe(selectedItem.value);
        expect(ciMinutesHandler).toHaveBeenCalledTimes(0);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledTimes(1);
        expect(ciMinutesProjectsHandler).toHaveBeenCalledWith({
          ...defaultPerMonthQueryVariables,
          date: '2022-03-01',
        });
      });
    });
  });
});
