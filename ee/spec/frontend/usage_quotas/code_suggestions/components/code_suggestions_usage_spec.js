import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import addOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import CodeSuggestionsInfo from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_statistics_card.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import { useFakeDate } from 'helpers/fake_date';
import CodeSuggestionsUsageLoader from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_loader.vue';
import DuoAmazonQInfoCard from 'ee/ai/settings/components/duo_amazon_q_info_card.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DUO_PRO, DUO_ENTERPRISE } from 'ee/constants/duo';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';

import {
  subscriptionActivationFutureDatedNotificationTitle,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from 'ee/admin/subscriptions/show/constants';

import {
  noAssignedDuoCoreAddOnData,
  noAssignedDuoProAddOnData,
  noAssignedDuoEnterpriseAddOnData,
  noAssignedDuoAmazonQAddOnData,
  noAssignedDuoAddOnsData,
  noPurchasedAddOnData,
  purchasedAddOnFuzzyData,
  currentLicenseData,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('GitLab Duo Usage', () => {
  // Aug 1, 2024
  useFakeDate(2024, 8, 1);

  let wrapper;

  const error = new Error('Something went wrong');

  const noAssignedDuoCoreAddOnDataHandler = jest.fn().mockResolvedValue(noAssignedDuoCoreAddOnData);
  const noAssignedDuoProAddOnDataHandler = jest.fn().mockResolvedValue(noAssignedDuoProAddOnData);
  const noAssignedDuoEnterpriseAddOnDataHandler = jest
    .fn()
    .mockResolvedValue(noAssignedDuoEnterpriseAddOnData);
  const noAssignedDuoAmazonQAddOnDataHandler = jest
    .fn()
    .mockResolvedValue(noAssignedDuoAmazonQAddOnData);
  const noAssignedDuoAddOnsDataHandler = jest.fn().mockResolvedValue(noAssignedDuoAddOnsData);
  const noPurchasedAddOnDataHandler = jest.fn().mockResolvedValue(noPurchasedAddOnData);
  const purchasedAddOnFuzzyDataHandler = jest.fn().mockResolvedValue(purchasedAddOnFuzzyData);
  const currentLicenseDataHandler = jest.fn().mockResolvedValue(currentLicenseData);

  const purchasedAddOnErrorHandler = jest.fn().mockRejectedValue(error);
  const currentLicenseErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = ({
    addOnPurchasesHandler = noPurchasedAddOnDataHandler,
    currentLicenseHandler = currentLicenseDataHandler,
  }) => {
    return createMockApollo([
      [addOnPurchasesQuery, addOnPurchasesHandler],
      [getCurrentLicense, currentLicenseHandler],
    ]);
  };

  const findCodeSuggestionsIntro = () => wrapper.findComponent(CodeSuggestionsIntro);
  const findCodeSuggestionsInfo = () => wrapper.findComponent(CodeSuggestionsInfo);
  const findCodeSuggestionsStatistics = () => wrapper.findComponent(CodeSuggestionsStatisticsCard);
  const findCodeSuggestionsSubtitle = () => wrapper.findByTestId('code-suggestions-subtitle');
  const findCodeSuggestionsTitle = () => wrapper.findByTestId('code-suggestions-title');
  const findAmazonQInfoCard = () => wrapper.findComponent(DuoAmazonQInfoCard);
  const findSaasAddOnEligibleUserList = () => wrapper.findComponent(SaasAddOnEligibleUserList);
  const findCodeSuggestionsUsageLoader = () => wrapper.findComponent(CodeSuggestionsUsageLoader);
  const findSelfManagedAddOnEligibleUserList = () =>
    wrapper.findComponent(SelfManagedAddOnEligibleUserList);
  const findErrorAlert = () => wrapper.findComponentByTestId('add-on-purchase-fetch-error');

  const findSubscriptionActivationSuccessAlert = () =>
    wrapper.findComponentByTestId('subscription-activation-success-alert');

  const findSubscriptionFetchErrorAlert = () =>
    wrapper.findComponentByTestId('subscription-fetch-error-alert');

  const createComponent = ({
    addOnPurchasesHandler,
    currentLicenseHandler,
    provideProps,
    waitForApi = true,
  } = {}) => {
    wrapper = shallowMountExtended(CodeSuggestionsUsage, {
      provide: {
        isSaaS: true,
        ...provideProps,
      },
      apolloProvider: createMockApolloProvider({
        addOnPurchasesHandler,
        currentLicenseHandler,
      }),
    });

    return waitForApi ? waitForPromises() : null;
  };

  describe('loading', () => {
    beforeEach(() => {
      createComponent({ waitForApi: false });
    });

    it('renders code suggestions usage loader', () => {
      expect(findCodeSuggestionsUsageLoader().exists()).toBe(true);
    });

    it('does not render any other usage components', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(false);
      expect(findCodeSuggestionsInfo().exists()).toBe(false);
      expect(findCodeSuggestionsStatistics().exists()).toBe(false);
      expect(findCodeSuggestionsTitle().exists()).toBe(false);
      expect(findSelfManagedAddOnEligibleUserList().exists()).toBe(false);
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('when no group id prop is provided', () => {
    beforeEach(() => {
      createComponent({ addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler });
    });
    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedDuoProAddOnDataHandler).toHaveBeenCalledWith({
        namespaceId: null,
      });
    });
  });

  describe('when group id prop is provided', () => {
    beforeEach(() => {
      createComponent({
        addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
        provideProps: { groupId: 289561 },
      });
    });
    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedDuoProAddOnDataHandler).toHaveBeenCalledWith({
        namespaceId: 'gid://gitlab/Group/289561',
      });
    });
  });

  describe('with no code suggestions data', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent();
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({ provideProps: { isSaaS: false } });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });
  });

  describe('with code suggestions data', () => {
    describe('when instance is SaaS', () => {
      describe('when on the seat utilization page', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
            provideProps: { groupId: 289561 },
          });
        });

        it('renders code suggestions title and pro tier badge', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            'Manage seat assignments for GitLab Duo Pro within your group.',
          );
        });
      });

      describe('with Duo Core add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoCoreAddOnDataHandler,
            provideProps: { groupId: 289561 },
          });
        });

        it('hides other components', () => {
          expect(findCodeSuggestionsIntro().exists()).toBe(false);
          expect(findCodeSuggestionsInfo().exists()).toBe(false);
          expect(findAmazonQInfoCard().exists()).toBe(false);
          expect(findCodeSuggestionsStatistics().exists()).toBe(false);
          expect(findSaasAddOnEligibleUserList().exists()).toBe(false);
          expect(findErrorAlert().exists()).toBe(false);
        });
      });

      describe('with Duo Pro add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
            provideProps: { groupId: 289561 },
          });
        });

        it('renders code suggestions statistics card for duo pro', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            activeDuoTier: DUO_PRO,
          });
        });

        it('renders code suggestions info card for duo pro', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: 289561,
            activeDuoTier: DUO_PRO,
          });
        });
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoEnterpriseAddOnDataHandler,
            provideProps: { groupId: 289561 },
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            activeDuoTier: DUO_ENTERPRISE,
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: 289561,
            activeDuoTier: DUO_ENTERPRISE,
          });
        });

        it('does not render amazon Q info card', () => {
          expect(findAmazonQInfoCard().exists()).toBe(false);
        });
      });

      describe('with Duo with Amazon Q add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoAmazonQAddOnDataHandler,
            provideProps: { groupId: 289561, isSaaS: false },
          });
        });

        it('does not render code suggestions statistics and info cards', () => {
          expect(findCodeSuggestionsStatistics().exists()).toBe(false);
          expect(findCodeSuggestionsInfo().exists()).toBe(false);
        });

        it('renders amazon Q info card', () => {
          expect(findAmazonQInfoCard().exists()).toBe(true);
        });
      });

      describe('with all Duo add-ons enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoAddOnsDataHandler,
            provideProps: { isSaaS: false, groupId: 289561 },
          });
        });

        it('selects the highest Duo tier', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            'Manage seat assignments for GitLab Duo with Amazon Q.',
          );
        });

        it('does render amazon Q info card', () => {
          expect(findAmazonQInfoCard().exists()).toBe(true);
        });
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchasesHandler: noAssignedDuoCoreAddOnDataHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          'Manage seat assignments for GitLab Duo Core.',
        );
      });

      it('hides other components', () => {
        expect(findAmazonQInfoCard().exists()).toBe(false);
        expect(findCodeSuggestionsInfo().exists()).toBe(false);
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
        expect(findCodeSuggestionsStatistics().exists()).toBe(false);
        expect(findErrorAlert().exists()).toBe(false);
        expect(findSaasAddOnEligibleUserList().exists()).toBe(false);
      });

      describe('with Duo Pro add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
            provideProps: { isSaaS: false },
          });
        });

        it('renders code suggestions title', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            'Manage seat assignments for GitLab Duo Pro.',
          );
        });

        it('renders code suggestions info card', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
        });
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoEnterpriseAddOnDataHandler,
            provideProps: { isSaaS: false },
          });
        });

        it('renders code suggestions title', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            'Manage seat assignments for GitLab Duo Enterprise.',
          );
        });

        it('renders code suggestions info card', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
        });
      });

      describe('with Duo Amazon Q add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoAmazonQAddOnDataHandler,
            provideProps: { isSaaS: false },
          });
        });

        it('renders code suggestions title', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            'Manage seat assignments for GitLab Duo with Amazon Q.',
          );
        });

        it('displays the Duo with Amazon Q card', () => {
          expect(findAmazonQInfoCard().exists()).toBe(true);
        });

        it('hides other components', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(false);
          expect(findCodeSuggestionsIntro().exists()).toBe(false);
          expect(findCodeSuggestionsStatistics().exists()).toBe(false);
          expect(findErrorAlert().exists()).toBe(false);
          expect(findSaasAddOnEligibleUserList().exists()).toBe(false);
        });
      });
    });
  });

  describe('add on eligible user list', () => {
    it('renders add-on user list for SaaS instance for SaaS', async () => {
      createComponent({
        addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
        provideProps: { isSaaS: true },
      });
      await waitForPromises();

      expect(findSaasAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        activeDuoTier: DUO_PRO,
      });
    });

    it('renders add-on user list for SM instance for SM', async () => {
      createComponent({
        addOnPurchasesHandler: noAssignedDuoProAddOnDataHandler,
        provideProps: { isSaaS: false },
      });
      await waitForPromises();

      expect(findSelfManagedAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        activeDuoTier: DUO_PRO,
      });
    });
  });

  describe('with fuzzy code suggestions data', () => {
    beforeEach(() => {
      return createComponent({ addOnPurchasesHandler: purchasedAddOnFuzzyDataHandler });
    });

    it('renders code suggestions intro', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(true);
    });
  });

  describe('with errors', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent({ addOnPurchasesHandler: purchasedAddOnErrorHandler });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(true);
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(true);
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchasesHandler: purchasedAddOnErrorHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title and pro tier badge', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          'Manage seat assignments for GitLab Duo Core.',
        );
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });
  });

  describe('Subscription Activation Form', () => {
    describe('activating the license', () => {
      beforeEach(async () => {
        createComponent({
          currentLicenseHandler: currentLicenseDataHandler,
          provideProps: { isSaaS: false },
        });

        await waitForPromises();
      });

      it('passes the correct data to the code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().props()).toMatchObject({
          subscription: currentLicenseData.data.currentLicense,
        });
      });

      it('shows the activation success notification', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2024-08-01',
        });

        await waitForPromises();

        expect(findSubscriptionActivationSuccessAlert().props('title')).toBe(
          'Your subscription was successfully activated.',
        );
      });

      it('shows the future dated activation success notification', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2025-08-01',
        });

        await waitForPromises();

        expect(findSubscriptionActivationSuccessAlert().props('title')).toBe(
          subscriptionActivationFutureDatedNotificationTitle,
        );
      });

      it('calls refetch to update component', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2025-08-01',
        });

        await waitForPromises();

        expect(noPurchasedAddOnDataHandler).toHaveBeenCalledTimes(2);
        expect(currentLicenseDataHandler).toHaveBeenCalledTimes(2);
      });
    });

    describe('when fetch subscription with error', () => {
      describe('when instance is SaaS', () => {
        beforeEach(async () => {
          createComponent({
            currentLicenseHandler: currentLicenseErrorHandler,
          });

          await waitForPromises();
        });

        it('does not show an error alert', () => {
          expect(currentLicenseErrorHandler).not.toHaveBeenCalled();
          expect(findSubscriptionFetchErrorAlert().exists()).toBe(false);
        });
      });

      describe('when instance is SM', () => {
        beforeEach(async () => {
          createComponent({
            currentLicenseHandler: currentLicenseErrorHandler,
            provideProps: { isSaaS: false },
          });

          await waitForPromises();
        });

        it('shows an error alert with cause', () => {
          expect(currentLicenseErrorHandler).toHaveBeenCalledTimes(1);
          expect(findSubscriptionFetchErrorAlert().props('title')).toBe('Subscription unavailable');
        });
      });
    });
  });
});
