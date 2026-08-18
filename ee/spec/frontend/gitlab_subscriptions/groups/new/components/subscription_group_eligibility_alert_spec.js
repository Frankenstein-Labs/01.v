import { GlAlert } from '@gitlab/ui';
import { ApolloError } from '@apollo/client';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SubscriptionGroupEligibilityAlert from 'ee/gitlab_subscriptions/groups/new/components/subscription_group_eligibility_alert.vue';

describe('SubscriptionGroupEligibilityAlert', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = mountExtended(SubscriptionGroupEligibilityAlert, {
      propsData: {
        planName: 'Premium',
        ...propsData,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('when error is provided', () => {
    const error = new ApolloError({
      graphQLErrors: [
        { message: 'This group already has an active subscription' },
        { message: 'This group type is not eligible for this plan' },
      ],
    });

    beforeEach(() => {
      createComponent({ error });
    });

    it('renders the alert with warning variant', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
    });

    it('displays the error message', () => {
      expect(wrapper.text()).toContain('This group already has an active subscription');
      expect(wrapper.text()).toContain('This group type is not eligible for this plan');
    });

    it('renders alert as non-dismissible', () => {
      expect(findAlert().props('dismissible')).toBe(false);
    });
  });

  describe('with different plan names', () => {
    it.each(['Premium', 'Ultimate', 'SaaS'])(
      'displays the correct title for %s plan',
      (planName) => {
        const error = new ApolloError({
          graphQLErrors: [{ message: 'Test error' }],
        });
        createComponent({ error, planName });

        expect(wrapper.text()).toContain(`This group is not eligible for ${planName}`);
      },
    );
  });
});
