import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('SubscriptionSeatsStatisticsCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createMockApolloProvider = (initialApolloData) => {
    const subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
      data: {
        subscription: {
          canAddSeats: true,
          canAddDuoProSeats: false,
          canRenew: false,
          communityPlan: Boolean(initialApolloData.communityPlan),
        },
        userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
      },
    });
    const handlers = [[getSubscriptionPermissionsData, subscriptionPermissionsQueryHandlerMock]];
    const mockCustomersDotClient = createMockClient(handlers);
    return new VueApollo({ clients: { customersDotClient: mockCustomersDotClient } });
  };

  const createWrapper = ({ initialApolloData = {}, props = {}, provide = {} } = {}) => {
    const apolloProvider = createMockApolloProvider(initialApolloData);
    wrapper = shallowMountExtended(SubscriptionSeatsStatisticsCard, {
      apolloProvider,
      propsData: {
        billableMembersCount: 3,
        activeTrial: false,
        seatsInSubscription: 13,
        ...props,
      },
      provide: {
        maxFreeNamespaceSeats: 5,
        namespaceId: 13,
        hasLimitedFreePlan: false,
        ...provide,
      },
    });
  };

  const findTooltipLink = () => wrapper.findComponent(GlLink);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUsageStatistics = () => wrapper.findComponent(UsageStatistics);
  const findUnlimitedSeatCountText = () => wrapper.findByText('You have unlimited seat count.');
  const findLimitedSeatCountText = () =>
    wrapper.findByText('Groups in the Free tier are limited to 5 seats');
  const findSeatsInfo = () => wrapper.findByTestId('seats-info');

  describe('when GraphQL data is loading', () => {
    it('renders <skeleton-loader> component', () => {
      createWrapper();

      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('with a free plan', () => {
    beforeEach(() => {
      const props = { hasFreePlan: true, seatsInSubscription: 0 };
      createWrapper({ props });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: null,
        totalValue: 'Unlimited',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(true);
      expect(findLimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Free seats used');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/manage_seats#gitlabcom-billing-and-usage',
      );
    });

    it('has tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe(
        'Learn more about billing and seat usage.',
      );
    });
  });

  describe('with a limited free plan', () => {
    beforeEach(() => {
      const provide = { hasLimitedFreePlan: true };
      const props = { hasFreePlan: true };
      createWrapper({ props, provide });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: null,
        totalValue: '5',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
      expect(findLimitedSeatCountText().exists()).toBe(true);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Free seats used');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/manage_seats#gitlabcom-billing-and-usage',
      );
    });

    it('has tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe('Free groups are limited to 5 seats.');
    });
  });

  describe('with an active trial', () => {
    beforeEach(() => {
      const provide = { hasLimitedFreePlan: true };
      createWrapper({ provide, props: { activeTrial: true } });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: null,
        totalValue: 'Unlimited',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
      expect(findLimitedSeatCountText().exists()).toBe(true);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Seats in use / Seats available');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/manage_seats#gitlabcom-billing-and-usage',
      );
    });

    it('has tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe(
        'Learn more about billing and seat usage.',
      );
    });
  });

  describe('with a community plan', () => {
    beforeEach(() => {
      const initialApolloData = { communityPlan: true };
      createWrapper({ initialApolloData });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: 23,
        totalValue: '13',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
      expect(findLimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Open source Plan Seats used');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(`${PROMO_URL}/solutions/open-source/`);
    });

    it('has tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe(
        'Learn more about billing and seat usage.',
      );
    });
  });

  describe('with a plan', () => {
    beforeEach(() => {
      const props = { hasFreePlan: false };
      createWrapper({ props });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: 23,
        totalValue: '13',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
      expect(findLimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Seats in use / Seats in subscription');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/manage_seats#gitlabcom-billing-and-usage',
      );
    });

    it('has tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe(
        'Learn more about billing and seat usage.',
      );
    });
  });
});
