import { GlButton } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { mockTracking } from 'helpers/tracking_helper';
import SubscriptionUpgradeInfoCard from 'ee/usage_quotas/seats/components/subscription_upgrade_info_card.vue';
import { EXPLORE_PAID_PLANS_CLICKED } from 'ee/usage_quotas/seats/constants';

describe('SubscriptionUpgradeInfoCard', () => {
  let trackingSpy;
  let wrapper;

  const defaultProps = {
    explorePlansPath: 'http://test.gitlab.com/',
  };

  const createComponent = (props = {}) => {
    wrapper = mount(SubscriptionUpgradeInfoCard, {
      propsData: { ...defaultProps, ...props },
      provide: {
        trialDuration: 30,
      },
    });
  };

  const findTitle = () => wrapper.find('[data-testid="title"]');
  const findDescription = () => wrapper.find('[data-testid="description"]');
  const findExplorePlansLink = () => wrapper.findComponent(GlButton);

  describe('default content', () => {
    beforeEach(() => {
      createComponent({ activeTrial: false });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('renders help link if description and helpLink props are passed', () => {
      expect(findExplorePlansLink().attributes('href')).toBe(defaultProps.explorePlansPath);
    });

    it('renders the title message', () => {
      expect(findTitle().text()).toContain('Add additional seats');
    });

    it('renders description message with max number of seats', () => {
      expect(findDescription().text()).toContain(
        'Start a free 30-day trial or upgrade to a paid tier to get an unlimited number of seats.',
      );
    });

    it('tracks on click', () => {
      const link = findExplorePlansLink();

      link.vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: EXPLORE_PAID_PLANS_CLICKED,
      });
    });
  });
});
