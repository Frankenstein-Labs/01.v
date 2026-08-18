import { GlButton, GlSprintf } from '@gitlab/ui';
import OverageOptInCard from 'ee/usage_quotas/usage_billing/components/overage_opt_in_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('OverageOptInCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(OverageOptInCard, {
      propsData: {
        customersUsageDashboardUrl: 'https://customers.gitlab.com/subscriptions/A-0123456/usage',
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('card title', () => {
      it('renders the correct title', () => {
        expect(wrapper.find('h2').text()).toBe("Keep your team's GitLab Duo features unblocked");
      });
    });

    describe('card body', () => {
      it('renders the correct body text', () => {
        expect(wrapper.find('p').text()).toMatchInterpolatedText(
          'Accept on-demand billing to keep GitLab Duo features active when monthly GitLab Credits run out. Without these terms, users lose GitLab Duo access after exhausting their included GitLab Credits. Learn about overage billing.',
        );
      });
    });

    describe('call to action button', () => {
      it('renders the correct button text', () => {
        const button = wrapper.findComponent(GlButton);
        expect(button.text()).toBe('Accept on-demand billing');
      });

      it('renders the button with the correct href', () => {
        const button = wrapper.findComponent(GlButton);
        expect(button.props('href')).toBe(
          'https://customers.gitlab.com/subscriptions/A-0123456/usage',
        );
      });
    });
  });
});
