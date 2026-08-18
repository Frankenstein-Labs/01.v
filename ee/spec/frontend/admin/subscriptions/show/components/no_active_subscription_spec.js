import { GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import CreditPurchaseCard from 'ee/admin/subscriptions/show/components/credit_purchase_card.vue';
import SubscriptionActivationCard from 'ee/admin/subscriptions/show/components/subscription_activation_card.vue';
import SubscriptionDetailsHistory from 'ee/admin/subscriptions/show/components/subscription_details_history.vue';
import NoActiveSubscription from 'ee_else_ce/admin/subscriptions/show/components/no_active_subscription.vue';
import CurrentPlanHeader from 'ee/vue_shared/subscription/components/current_plan_header.vue';
import UpgradePlanHeader from 'ee/vue_shared/subscription/components/upgrade_plan_header.vue';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import {
  instanceHasFutureLicenseBanner,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from 'ee/admin/subscriptions/show/constants';
import { useFakeDate } from 'helpers/fake_date';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { sprintf } from '~/locale';
import { license, subscriptionFutureHistory, subscriptionPastHistory } from '../mock_data';

Vue.use(VueApollo);

describe('NoActiveSubscription', () => {
  // March 16th, 2020
  useFakeDate(2021, 2, 16);

  let wrapper;

  const findActivateSubscriptionCard = () => wrapper.findComponent(SubscriptionActivationCard);
  const findCreditPurchaseCard = () => wrapper.findComponent(CreditPurchaseCard);
  const findSubscriptionDetailsHistory = () => wrapper.findComponent(SubscriptionDetailsHistory);
  const findSubscriptionFutureLicensesAlert = () =>
    wrapper.findByTestId('subscription-future-licenses-alert');

  const provideProps = {
    freeTrialPath: 'free/trial/path',
    groupsCount: 10,
    projectsCount: 9,
    usersCount: 8,
    purchaseCreditsPath: 'https://customers.gitlab.com/subscriptions/purchases/gitlab',
    monthlyCommitmentPurchased: 0,
    creditsFetchError: false,
  };

  const createComponent = (props, listeners) => {
    wrapper = shallowMountExtended(NoActiveSubscription, {
      propsData: props,
      listeners,
      provide: provideProps,
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('without future subscriptions/licenses', () => {
    beforeEach(() => {
      createComponent({
        subscriptionList: subscriptionPastHistory,
      });
    });

    it('shows the past items', () => {
      expect(findSubscriptionDetailsHistory().exists()).toBe(true);
      expect(findSubscriptionDetailsHistory().props()).toMatchObject({
        subscriptionList: subscriptionPastHistory,
      });
    });
  });

  describe('Empty', () => {
    beforeEach(() => {
      createComponent({
        subscriptionList: [],
      });
    });

    it('expect empty', () => {
      expect(findSubscriptionDetailsHistory().exists()).toBe(false);
    });
  });

  describe('with future subscriptions/licenses', () => {
    beforeEach(() => {
      createComponent({
        subscriptionList: [...subscriptionPastHistory, ...subscriptionFutureHistory],
      });
    });

    it('shows the upcoming license notification', () => {
      expect(findSubscriptionFutureLicensesAlert().exists()).toBe(true);
    });

    it('shows the upcoming license date in the notification', () => {
      // Getting the next future dated license start date
      const nextLicenseStartDate = [...subscriptionPastHistory, ...subscriptionFutureHistory]
        .filter(({ startsAt }) => isInFuture(new Date(startsAt)))
        .sort((a, b) => Date(a) - Date(b))
        .pop().startsAt;

      const expectedText = sprintf(instanceHasFutureLicenseBanner.message, {
        date: nextLicenseStartDate,
      });
      expect(findSubscriptionFutureLicensesAlert().text()).toBe(expectedText);
    });

    it('shows the upcoming licenses', () => {
      expect(findSubscriptionDetailsHistory().exists()).toBe(true);
      expect(findSubscriptionDetailsHistory().props()).toMatchObject({
        subscriptionList: [...subscriptionPastHistory, ...subscriptionFutureHistory],
      });
    });
  });

  describe('CreditPurchaseCard', () => {
    it('renders the credit purchase card', () => {
      createComponent({ subscriptionList: [] });
      expect(findCreditPurchaseCard().exists()).toBe(true);
    });
  });

  describe('Activation form', () => {
    let onSuccess;

    beforeEach(() => {
      onSuccess = jest.fn();
      createComponent(
        {
          subscriptionList: [],
        },
        {
          [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT]: onSuccess,
        },
      );
    });

    it('shows the subscription activation form', () => {
      expect(findActivateSubscriptionCard().exists()).toBe(true);
    });

    it('passes activation card events', async () => {
      findActivateSubscriptionCard().vm.$emit(
        SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
        license.ULTIMATE,
      );
      await nextTick();

      expect(onSuccess).toHaveBeenCalledWith(license.ULTIMATE);
    });
  });

  describe('Plan headers', () => {
    beforeEach(() => {
      createComponent({
        subscriptionList: [],
      });
    });

    it('shows the current plan header', () => {
      expect(wrapper.findComponent(CurrentPlanHeader).exists()).toBe(true);
      expect(wrapper.findComponent(CurrentPlanHeader).props()).toMatchObject({
        seatsInUse: provideProps.usersCount,
        totalProjects: provideProps.projectsCount,
        totalGroups: provideProps.groupsCount,
        trialActive: false,
        isSaas: false,
      });
    });

    it('shows the upgrade plan header', () => {
      expect(wrapper.findComponent(UpgradePlanHeader).exists()).toBe(true);
      expect(wrapper.findComponent(UpgradePlanHeader).props()).toMatchObject({
        trialActive: false,
        trialExpired: false,
        startTrialPath: provideProps.freeTrialPath,
        canAccessDuoChat: false,
        isSaas: false,
      });
    });
  });
});
