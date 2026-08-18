import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import FreeTierTrialApp from 'ee/usage_quotas/usage_billing/components/free_tier_trial_app.vue';
import TrialUsageByUserTab from 'ee/usage_quotas/usage_billing/components/trial_usage_by_user_tab.vue';
import UpgradeToPremiumCard from 'ee/usage_quotas/usage_billing/components/upgrade_to_premium_card.vue';
import FreeTierPurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/free_tier_purchase_commitment_card.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import getTrialUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_trial_usage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const mockTrialUsageData = {
  data: {
    trialUsage: {
      activeTrial: {
        startDate: '2026-01-01',
        endDate: '2026-01-31',
      },
      usersUsage: {
        creditsUsed: 100,
        totalUsersUsingCredits: 5,
      },
    },
  },
};

describe('FreeTierTrialApp', () => {
  let wrapper;
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({
    mockQueryHandler = jest.fn().mockResolvedValue(mockTrialUsageData),
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(FreeTierTrialApp, {
      apolloProvider: createMockApollo([[getTrialUsageQuery, mockQueryHandler]]),
      provide: {
        namespacePath: 'test-namespace',
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingState = () => wrapper.findByTestId('trial-loading-state');
  const findUpgradeToPremiumCard = () => wrapper.findComponent(UpgradeToPremiumCard);
  const findFreeTierPurchaseCommitmentCard = () =>
    wrapper.findComponent(FreeTierPurchaseCommitmentCard);
  const findTrialUsageByUserTab = () => wrapper.findComponent(TrialUsageByUserTab);
  const findHumanTimeframe = () => wrapper.findComponent(HumanTimeframe);

  describe('page header', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the page title with trial badge', () => {
      expect(findPageHeading().text()).toContain('GitLab Credits');
      expect(findPageHeading().text()).toContain('(Trial)');
    });

    it('renders the trial period', () => {
      const timeframe = findHumanTimeframe();
      expect(timeframe.exists()).toBe(true);
      expect(timeframe.props('from')).toBe('2026-01-01');
      expect(timeframe.props('till')).toBe('2026-01-31');
    });

    it('shows "Trial period:" label', () => {
      expect(wrapper.text()).toContain('Trial period:');
    });
  });

  describe('loading state', () => {
    it('shows loading skeleton when loading', () => {
      createComponent();
      expect(findLoadingState().exists()).toBe(true);
    });

    it('hides loading skeleton after data loads', async () => {
      createComponent();
      await waitForPromises();
      expect(findLoadingState().exists()).toBe(false);
    });
  });

  describe('error state', () => {
    it('shows error alert when API request fails', async () => {
      const error = new Error('GraphQL error');
      createComponent({
        mockQueryHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('An error occurred while fetching data');
    });

    it('logs the error to console and Sentry', async () => {
      const error = new Error('GraphQL error');
      createComponent({
        mockQueryHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      expect(logError).toHaveBeenCalledWith(error);
      expect(captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('trial usage cards', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders UpgradeToPremiumCard', () => {
      expect(findUpgradeToPremiumCard().exists()).toBe(true);
    });

    it('renders FreeTierPurchaseCommitmentCard', () => {
      expect(findFreeTierPurchaseCommitmentCard().exists()).toBe(true);
    });
  });

  describe('usage by user tab', () => {
    beforeEach(() => {
      window.gon = { display_gitlab_credits_user_data: true };
    });

    afterEach(() => {
      delete window.gon;
    });

    it('renders TrialUsageByUserTab when user data is enabled', async () => {
      createComponent();
      await waitForPromises();
      expect(findTrialUsageByUserTab().exists()).toBe(true);
    });

    it('shows disabled alert when user data is disabled', async () => {
      window.gon.display_gitlab_credits_user_data = false;
      createComponent();
      await waitForPromises();

      const alert = wrapper.findByTestId('user-data-disabled-alert');
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain('Displaying user data is disabled');
    });
  });

  describe('tracking', () => {
    it('tracks pageview on component mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(document);
      createComponent();

      expect(trackEventSpy).toHaveBeenCalledWith('view_usage_billing_pageload', {}, undefined);
    });

    it('uses InternalEvents mixin for tracking', () => {
      createComponent();
      expect(wrapper.vm.trackEvent).toBeDefined();
    });
  });

  describe('computed properties', () => {
    describe('inFreeTierTrial', () => {
      it('returns true when activeTrial exists', async () => {
        createComponent();
        await waitForPromises();
        expect(wrapper.vm.inFreeTierTrial).toBe(true);
      });

      it('returns false when activeTrial is null', async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue({
            data: { trialUsage: { activeTrial: null } },
          }),
        });
        await waitForPromises();
        expect(wrapper.vm.inFreeTierTrial).toBe(false);
      });
    });
  });
});
