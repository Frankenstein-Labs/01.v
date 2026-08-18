import { GlCard, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import SubscriptionDetailsUserInfo from 'ee/admin/subscriptions/show/components/subscription_details_user_info.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import { license } from '../mock_data';

describe('Subscription Details User Info', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findUsersInSubscriptionDesc = () => wrapper.findByTestId('users-in-subscription-desc');
  const findBillableUsersCard = () => wrapper.findByTestId('billable-users');
  const findMaximumUsersCard = () => wrapper.findByTestId('maximum-users');
  const findUsersOverLicenseCard = () => wrapper.findByTestId('users-over-license');
  const findSubscriptionText = () => wrapper.findByTestId('users-in-subscription-content').text();

  const createComponent = ({ props = {}, stubGlSprintf = false } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(SubscriptionDetailsUserInfo, {
        propsData: {
          subscription: { ...license.ULTIMATE, plan: 'premium' },
          ...props,
        },
        stubs: {
          GlCard,
          HelpPageLink,
          GlSprintf: stubGlSprintf ? GlSprintf : true,
        },
      }),
    );
  };

  describe('Users is subscription card', () => {
    it('should display the value when present', () => {
      const subscription = { ...license.ULTIMATE, usersInLicenseCount: 0, plan: 'premium' };
      createComponent({ props: { subscription } });

      expect(findSubscriptionText()).toBe('0');
    });

    it('should display Unlimited when users in license is null', () => {
      const subscription = { ...license.ULTIMATE, usersInLicenseCount: null, plan: 'premium' };
      createComponent({ props: { subscription } });

      expect(findSubscriptionText()).toBe('Unlimited');
    });

    it('does not render card description', () => {
      const subscription = { ...license.ULTIMATE, usersInLicenseCount: 0, plan: 'premium' };
      createComponent({ props: { subscription } });

      expect(findUsersInSubscriptionDesc().exists()).toBe(false);
    });

    describe('when subscription is ultimate', () => {
      it('renders text in the card "Users in Subscription"', () => {
        const subscription = { ...license.ULTIMATE };
        createComponent({ props: { subscription } });

        expect(findUsersInSubscriptionDesc().exists()).toBe(true);
      });
    });
  });

  describe('Billable users', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the billable users total', () => {
      expect(findBillableUsersCard().find('h3').text()).toBe(license.ULTIMATE.billableUsersCount);
    });

    it('displays the title', () => {
      expect(findBillableUsersCard().find('h2').text()).toBe('Billable users');
    });

    it('displays the copy', () => {
      expect(findBillableUsersCard().findComponent(GlSprintf).attributes('message')).toBe(
        'This is the number of %{billableUsersLinkStart}billable users%{billableUsersLinkEnd} on your installation, and this is the minimum number you need to purchase when you renew your license.',
      );
    });

    it('has a link', () => {
      createComponent({ stubGlSprintf: true });

      expect(findBillableUsersCard().findComponent(HelpPageLink).attributes('href')).toBe(
        '/help/subscriptions/manage_seats#billable-users',
      );
    });
  });

  describe('Maximum users', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the title', () => {
      expect(findMaximumUsersCard().find('h2').text()).toBe('Maximum users');
    });

    it('displays the max users total', () => {
      expect(findMaximumUsersCard().find('h3').text()).toBe(license.ULTIMATE.maximumUserCount);
    });
  });

  describe('Users over subscription', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the title', () => {
      expect(findUsersOverLicenseCard().find('h2').text()).toBe('Users over subscription');
    });

    it('displays the max users total', () => {
      expect(findUsersOverLicenseCard().find('h3').text()).toBe(
        license.ULTIMATE.usersOverLicenseCount,
      );
    });

    it('displays the copy', () => {
      expect(findUsersOverLicenseCard().findComponent(GlSprintf).attributes('message')).toBe(
        "You'll be charged for %{trueUpLinkStart}users over license%{trueUpLinkEnd} on a quarterly or annual basis, depending on the terms of your agreement.",
      );
    });

    it('has a link', () => {
      createComponent({ stubGlSprintf: true });

      expect(findUsersOverLicenseCard().findComponent(PromoPageLink).attributes('path')).toBe(
        '/pricing/licensing-faq/#what-does-users-over-license-mean',
      );
    });
  });
});
