import { shallowMount } from '@vue/test-utils';
import MetaApp from 'ee/usage_quotas/usage_billing/components/meta_app.vue';
import FreeTierTrialApp from 'ee/usage_quotas/usage_billing/components/free_tier_trial_app.vue';
import PaidSubscriptionApp from 'ee/usage_quotas/usage_billing/components/app.vue';

describe('UsageBillingMetaApp', () => {
  let wrapper;

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(MetaApp, {
      provide: {
        isFree: false,
        ...provide,
      },
    });
  };

  const findFreeTierTrialApp = () => wrapper.findComponent(FreeTierTrialApp);
  const findPaidSubscriptionApp = () => wrapper.findComponent(PaidSubscriptionApp);

  describe('routing based on isFree flag', () => {
    it('renders FreeTierTrialApp when isFree is true', () => {
      createComponent({ provide: { isFree: true } });

      expect(findFreeTierTrialApp().exists()).toBe(true);
      expect(findPaidSubscriptionApp().exists()).toBe(false);
    });

    it('renders PaidSubscriptionApp when isFree is false', () => {
      createComponent({ provide: { isFree: false } });

      expect(findFreeTierTrialApp().exists()).toBe(false);
      expect(findPaidSubscriptionApp().exists()).toBe(true);
    });

    it('renders PaidSubscriptionApp by default when isFree is not provided', () => {
      createComponent();

      expect(findFreeTierTrialApp().exists()).toBe(false);
      expect(findPaidSubscriptionApp().exists()).toBe(true);
    });
  });
});
