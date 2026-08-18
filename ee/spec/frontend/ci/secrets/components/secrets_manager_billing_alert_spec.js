import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretsManagerBillingAlert from 'ee/ci/secrets/components/secrets_manager_billing_alert.vue';

describe('SecretsManagerBillingAlert', () => {
  let wrapper;
  const createComponent = ({ entitlement = {}, secretsManagerPaidExperience = false } = {}) => {
    wrapper = shallowMountExtended(SecretsManagerBillingAlert, {
      propsData: {
        entitlement: {
          onDemandEnabled: false,
          ...entitlement,
        },
      },
      provide: {
        glFeatures: { secretsManagerPaidExperience },
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findBillingAlert = () => wrapper.findByTestId('billing-alert');
  const findDocsLink = () => wrapper.findComponent(GlLink);
  const findOpenBetaBillingAlert = () => wrapper.findByTestId('open-beta-billing-alert');

  describe('when secretsManagerPaidExperience feature flag is disabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders open beta alert and not the billing alert', () => {
      expect(findOpenBetaBillingAlert().exists()).toBe(true);
      expect(findBillingAlert().exists()).toBe(false);
    });

    it('renders the correct docs link', () => {
      expect(findDocsLink().props('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
    });
  });

  describe('when secretsManagerPaidExperience feature flag is enabled', () => {
    beforeEach(() => {
      createComponent({ secretsManagerPaidExperience: true });
    });

    it('renders billing alert and not the open beta alert', () => {
      expect(findBillingAlert().exists()).toBe(true);
      expect(findOpenBetaBillingAlert().exists()).toBe(false);
    });

    it('renders the correct docs link', () => {
      expect(findDocsLink().props('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
    });

    describe('when on-demand is enabled', () => {
      beforeEach(() => {
        createComponent({
          secretsManagerPaidExperience: true,
          entitlement: { onDemandEnabled: true },
        });
      });

      it('shows on-demand enabled title when on-demand is enabled', () => {
        expect(findBillingAlert().findComponent(GlAlert).props('title')).toBe(
          'On-demand is enabled',
        );
      });
    });

    describe('when on-demand is disabled', () => {
      beforeEach(() => {
        createComponent({
          secretsManagerPaidExperience: true,
          entitlement: { onDemandEnabled: false },
        });
      });

      it('shows on-demand enabled title when on-demand is enabled', () => {
        expect(findBillingAlert().findComponent(GlAlert).props('title')).toBe(
          'Enable on-demand billing to try GitLab Secrets Manager',
        );
      });
    });
  });
});
