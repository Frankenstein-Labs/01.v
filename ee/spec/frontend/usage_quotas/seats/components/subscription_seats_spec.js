import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import SubscriptionUpgradeInfoCard from 'ee/usage_quotas/seats/components/subscription_upgrade_info_card.vue';
import SubscriptionSeats from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import SubscriptionUserList from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import {
  createMockFreeSubscription,
  createMockUltimateSubscription,
} from 'ee_jest/usage_quotas/seats/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const providedFields = {
  explorePlansPath: '/groups/test_group/-/billings',
  activeTrial: false,
  addSeatsHref: '/groups/test_group/-/seat_usage.csv',
};

const defaultSubscriptionPlanData = createMockUltimateSubscription({
  maxSeatsUsed: 3,
  seatsOwed: 1,
});

const freeSubscriptionPlanData = createMockFreeSubscription({ id: 2 });

describe('SubscriptionSeats', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const fullPath = 'group-path';
  const { explorePlansPath, addSeatsHref } = providedFields;

  /** @type { jest.Mock } */
  let subscriptionQueryResolver;
  /** @type { jest.Mock } */
  let getBillableMembersCountQueryHandler;

  const createComponent = ({ provide = {} } = {}) => {
    const resolvers = {
      Query: {
        subscription: subscriptionQueryResolver,
      },
    };

    const apolloProvider = createMockApollo(
      [[getBillableMembersCountQuery, getBillableMembersCountQueryHandler]],
      resolvers,
    );

    wrapper = extendedWrapper(
      shallowMount(SubscriptionSeats, {
        apolloProvider,
        provide: {
          fullPath,
          isPublicNamespace: false,
          explorePlansPath,
          addSeatsHref,
          namespaceId: 1,
          hasLimitedFreePlan: false,
          ...provide,
        },
      }),
    );

    return waitForPromises();
  };

  const findPublicNamespacePlanInfoCard = () => wrapper.findComponent(PublicNamespacePlanInfoCard);
  const findSubscriptionSeatsStatisticsCard = () =>
    wrapper.findComponent(SubscriptionSeatsStatisticsCard);
  const findStatisticsSeatsCard = () => wrapper.findComponent(StatisticsSeatsCard);
  const findSubscriptionUpgradeCard = () => wrapper.findComponent(SubscriptionUpgradeInfoCard);
  const findSubscriptionUserList = () => wrapper.findComponent(SubscriptionUserList);
  const findSkeletonLoaderCards = () => wrapper.findByTestId('skeleton-loader-cards');

  beforeEach(() => {
    getBillableMembersCountQueryHandler = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/13',
          billableMembersCount: 2,
          enforceFreeUserCap: false,
        },
      },
    });

    subscriptionQueryResolver = jest.fn().mockResolvedValue(defaultSubscriptionPlanData);
  });

  describe('statistics cards', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('renders <subscription-seats-statistics-card> with the necessary props', () => {
      expect(findSubscriptionSeatsStatisticsCard().props()).toMatchObject({
        billableMembersCount: 2,
        seatsInSubscription: 0,
      });
    });

    it('renders <statistics-seats-card> with the necessary props', () => {
      const statisticsSeatsCard = findStatisticsSeatsCard();

      expect(findSubscriptionUpgradeCard().exists()).toBe(false);
      expect(statisticsSeatsCard.exists()).toBe(true);
      expect(statisticsSeatsCard.props()).toMatchObject({
        hasFreePlan: false,
        seatsOwed: 1,
        seatsUsed: 3,
      });
    });

    describe('when on free namespace', () => {
      beforeEach(() => {
        subscriptionQueryResolver.mockResolvedValue(freeSubscriptionPlanData);
        return createComponent();
      });

      it('renders <statistics-seats-card> with hasFreePlan as true', () => {
        expect(findStatisticsSeatsCard().props('hasFreePlan')).toBe(true);
      });
    });

    describe('for free namespace with limit', () => {
      beforeEach(() => {
        return createComponent({
          provide: {
            hasLimitedFreePlan: true,
          },
        });
      });

      it('renders <subscription-upgrade-info-card> with the necessary props', () => {
        const upgradeInfoCard = findSubscriptionUpgradeCard();

        expect(findStatisticsSeatsCard().exists()).toBe(false);
        expect(upgradeInfoCard.exists()).toBe(true);
        expect(upgradeInfoCard.props()).toMatchObject({
          explorePlansPath: providedFields.explorePlansPath,
        });
      });
    });

    describe('when is a public namespace', () => {
      beforeEach(() => {
        subscriptionQueryResolver.mockResolvedValue(freeSubscriptionPlanData);
        return createComponent({
          provide: {
            isPublicNamespace: true,
          },
        });
      });

      it('renders <public-namespace-plan-info-card>', () => {
        expect(findPublicNamespacePlanInfoCard().exists()).toBe(true);
      });
    });
  });

  describe('subscription user list', () => {
    it('renders subscription users', async () => {
      await createComponent();
      expect(findSubscriptionUserList().exists()).toBe(true);
    });

    it('refetches data when findSubscriptionUserList emits refetch-data', async () => {
      await createComponent();

      // Initial queries should have been called once
      expect(subscriptionQueryResolver).toHaveBeenCalledTimes(1);
      expect(getBillableMembersCountQueryHandler).toHaveBeenCalledTimes(1);

      await findSubscriptionUserList().vm.$emit('refetch-data');

      // After refetch, queries should have been called twice more
      expect(subscriptionQueryResolver).toHaveBeenCalledTimes(2);
      expect(getBillableMembersCountQueryHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('Loading state', () => {
    beforeEach(() => {
      getBillableMembersCountQueryHandler.mockImplementation(() => new Promise(() => {}));
      subscriptionQueryResolver.mockImplementation(() => new Promise(() => {}));
      return createComponent();
    });

    it('displays the loading skeleton', () => {
      expect(findSkeletonLoaderCards().exists()).toBe(true);
    });

    it('hides the <subscription-seats-statistics-card>', () => {
      expect(findSubscriptionSeatsStatisticsCard().exists()).toBe(false);
    });

    it('hides the <statistics-seats-card>', () => {
      expect(findStatisticsSeatsCard().exists()).toBe(false);
    });
  });

  describe('Error handling', () => {
    const ERROR = new Error('error');

    describe('when getBillableMembersCount query fails', () => {
      beforeEach(() => {
        getBillableMembersCountQueryHandler.mockRejectedValue(ERROR);
        return createComponent();
      });

      it('calls createAlert when gitlab subscription query fails', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while loading billable members list.',
        });
      });

      it('logs the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(ERROR);
      });
    });

    describe('when gitlab subscription query fails', () => {
      beforeEach(() => {
        subscriptionQueryResolver.mockRejectedValue(ERROR);
        return createComponent();
      });

      it('calls createAlert when gitlab subscription query fails', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while loading GitLab subscription details.',
        });
      });

      it('logs the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(ERROR);
      });
    });
  });
});
