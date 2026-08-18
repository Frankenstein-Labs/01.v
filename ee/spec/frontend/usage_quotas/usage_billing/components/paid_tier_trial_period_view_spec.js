import { GlButton, GlCard, GlLink, GlSprintf } from '@gitlab/ui';
import PaidTierTrialPeriodView from 'ee/usage_quotas/usage_billing/components/paid_tier_trial_period_view.vue';
import UsageOverviewChart from 'ee/usage_quotas/usage_billing/components/usage_overview_chart.vue';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

describe('PaidTierTrialPeriodView', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const defaultProps = {
    customersUsageDashboardUrl: 'https://customers.gitlab.com/dashboard',
    purchaseCreditsUrl: 'https://customers.gitlab.com/purchase/credits',
    monthStartDate: '2025-10-01',
    monthEndDate: '2025-10-31',
    commitmentDailyUsage: [],
    waiverDailyUsage: [],
    overageDailyUsage: [],
    paidTierTrialDailyUsage: [],
    usersUsageDailyUsage: [],
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PaidTierTrialPeriodView, {
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('header', () => {
      const findHeaderCard = () => wrapper.findByTestId('paid-tier-trial-header-card');

      it('renders the alert with info variant', () => {
        const headerCard = findHeaderCard();

        expect(headerCard.exists()).toBe(true);
        expect(headerCard.text()).toContain('Your GitLab evaluation credits are active');
      });

      it('renders link to the Customers portal', () => {
        const headerCardPrimaryButton = findHeaderCard().findComponent(GlButton);

        expect(headerCardPrimaryButton.exists()).toBe(true);
        expect(headerCardPrimaryButton.props('href')).toBe(
          'https://customers.gitlab.com/dashboard',
        );
      });
    });

    describe('usage overview tab', () => {
      it('renders UsageOverviewChart with correct props', () => {
        const paidTierTrialDailyUsage = [{ creditsUsed: 15, date: '2025-10-05' }];
        const usersUsageDailyUsage = [{ creditsUsed: 5, date: '2025-10-01' }];

        createComponent({
          propsData: { paidTierTrialDailyUsage, usersUsageDailyUsage },
        });

        const chart = wrapper.findComponent(UsageOverviewChart);

        expect(chart.exists()).toBe(true);
        expect(chart.props()).toMatchObject({
          monthStartDate: '2025-10-01',
          monthEndDate: '2025-10-31',
          paidTierTrialDailyUsage,
          usersUsageDailyUsage,
        });
      });
    });

    describe('usage by user tab', () => {
      it('renders UsageByUserTab when user data display is enabled', () => {
        gon.display_gitlab_credits_user_data = true;
        createComponent();

        expect(wrapper.findComponent(UsageByUserTab).exists()).toBe(true);
      });

      it('renders disabled message when user data display is not enabled', () => {
        gon.display_gitlab_credits_user_data = false;
        createComponent();

        expect(wrapper.findComponent(UsageByUserTab).exists()).toBe(false);
        expect(wrapper.findByTestId('user-data-disabled-alert').exists()).toBe(true);
      });
    });

    describe('secondary cards', () => {
      const findSecondaryCardsSection = () => wrapper.findByTestId('paid-tier-trial-body');

      describe('continue after your evaluation card', () => {
        const findFirstCard = () => findSecondaryCardsSection().findAllComponents(GlCard).at(0);

        it('renders the card', () => {
          const card = findFirstCard();

          expect(card.exists()).toBe(true);
          expect(card.text()).toContain('Continue after your evaluation');
        });

        it('renders the link with the correct href', () => {
          const linkComponent = findFirstCard().findComponent(GlLink);

          expect(linkComponent.exists()).toBe(true);
          expect(linkComponent.attributes('href')).toBe(
            'https://customers.gitlab.com/purchase/credits',
          );
        });

        describe('when purchase flow is not available', () => {
          beforeEach(() => {
            createComponent({
              propsData: {
                purchaseCreditsUrl: null,
              },
            });
          });

          it('does not render the card', () => {
            const card = findFirstCard();

            expect(card.exists()).toBe(true);
            expect(card.text()).not.toContain('Continue after your evaluation');
          });
        });
      });

      describe('learn about GitLab Credits card', () => {
        const findSecondCard = () => findSecondaryCardsSection().findAllComponents(GlCard).at(1);

        it('renders the card', () => {
          const card = findSecondCard();

          expect(card.text()).toContain('Learn about GitLab Credits');
        });

        it('renders documentation link', () => {
          const link = findSecondCard().findComponent(HelpPageLink);

          expect(link.attributes('href')).toBe('subscriptions/gitlab_credits');
          expect(link.text()).toBe('Read the documentation');
        });
      });

      describe('explore GitLab Duo card', () => {
        const findThirdCard = () => findSecondaryCardsSection().findAllComponents(GlCard).at(2);

        it('renders the card', () => {
          const card = findThirdCard();

          expect(card.text()).toContain('Explore GitLab Duo');
        });

        it('renders documentation link', () => {
          const link = findThirdCard().findComponent(HelpPageLink);

          expect(link.attributes('href')).toBe('user/gitlab_duo/_index');
          expect(link.text()).toBe('Learn more about GitLab Duo');
        });
      });
    });
  });
});
