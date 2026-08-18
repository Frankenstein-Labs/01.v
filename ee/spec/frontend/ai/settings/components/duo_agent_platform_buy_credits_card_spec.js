import { GlIntersectionObserver, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformBuyCreditsCard from 'ee/ai/settings/components/duo_agent_platform_buy_credits_card.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { PROMO_URL } from '~/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { mockTracking } from 'helpers/tracking_helper';

describe('DuoAgentPlatformBuyCreditsCard', () => {
  let wrapper;

  const gitlabComPurchaseCreditsPath =
    'https://customers.gitlab.com/subscriptions/purchases/gitlab?plan_type=gitlab_credits';

  const selfManagedPurchaseCreditsPath = '#';

  const createComponent = ({
    isSaaS = false,
    gitlabComPurchaseCreditsPath: creditsPath = '',
    namespaceIsOnTrial = false,
    showSmPurchaseButton = false,
    isSmTrial = false,
    selfManagedPurchaseCreditsPath: smCreditsPath = '',
    hasGitlabCredits = false,
    creditsGeneralizationUi = false,
  } = {}) => {
    wrapper = shallowMountExtended(DuoAgentPlatformBuyCreditsCard, {
      provide: {
        isSaaS,
        gitlabComPurchaseCreditsPath: creditsPath,
        namespaceIsOnTrial,
        showSmPurchaseButton,
        isSmTrial,
        selfManagedPurchaseCreditsPath: smCreditsPath,
        creditsGeneralizationUi,
      },
      propsData: {
        hasGitlabCredits,
      },
    });
  };

  const findCardFooter = () => wrapper.findByTestId('credits-card-footer');
  const findTalkToSalesLink = () =>
    wrapper.findComponentByTestId('duo-agent-platform-talk-to-sales-link');
  const findHandRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);
  const findPurchaseCreditsLink = () =>
    wrapper.findByTestId('duo-agent-platform-purchase-credits-link');
  const findFooterPurchaseCreditsLink = () => {
    const footer = findCardFooter();
    return footer.exists()
      ? footer.find('[data-testid="duo-agent-platform-purchase-credits-link"]')
      : footer;
  };
  const findLearnMoreLink = () => wrapper.findByTestId('duo-agent-platform-learn-more-link');

  describe('component rendering', () => {
    it('displays title and description', () => {
      createComponent();

      expect(wrapper.text()).toContain('Buy Credits');
      expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
      expect(wrapper.text()).toContain(
        'Orchestrate AI agents across your entire software lifecycle to automate complex workflows, accelerate delivery, and keep your team in flow',
      );
    });

    describe('when on SaaS', () => {
      beforeEach(() => {
        createComponent({ isSaaS: true });
      });

      it('renders HandRaiseLeadButton with correct props', () => {
        const handRaiseButton = findHandRaiseLeadButton();
        expect(handRaiseButton.exists()).toBe(true);
        expect(handRaiseButton.props()).toMatchObject({
          buttonAttributes: {
            variant: 'confirm',
            category: 'primary',
            'data-testid': 'duo-agent-platform-talk-to-sales-action',
          },
          glmContent: 'duo_agent_platform_buy_credits',
          ctaTracking: {
            action: 'click_button',
            label: 'duo_agent_platform_buy_credits_card_talk_to_sales',
          },
          productInteraction: 'Hand Raise PQL',
          buttonText: 'Talk to Sales',
        });
      });

      it('does not render direct link button', () => {
        expect(findTalkToSalesLink().exists()).toBe(false);
      });

      it('does not render purchase credits button', () => {
        expect(findPurchaseCreditsLink().exists()).toBe(false);
      });

      it('does not render learn more button', () => {
        expect(findLearnMoreLink().exists()).toBe(false);
      });
    });

    describe('when on Self-Managed', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false });
      });

      it('renders direct link button with correct attributes', () => {
        const button = findTalkToSalesLink();
        expect(button.exists()).toBe(true);
        expect(button.attributes('href')).toBe(`${PROMO_URL}/sales/`);
        expect(button.text()).toBe('Talk to Sales');
      });

      it('does not render HandRaiseLeadButton', () => {
        expect(findHandRaiseLeadButton().exists()).toBe(false);
      });

      it('does not render purchase credits button', () => {
        expect(findPurchaseCreditsLink().exists()).toBe(false);
      });

      it('does not render learn more button', () => {
        expect(findLearnMoreLink().exists()).toBe(false);
      });
    });

    describe('when on Self-Managed with showSmPurchaseButton and selfManagedPurchaseCreditsPath provided', () => {
      beforeEach(() => {
        createComponent({
          isSaaS: false,
          showSmPurchaseButton: true,
          selfManagedPurchaseCreditsPath,
        });
      });

      it('displays monthly commitment title and description', () => {
        expect(wrapper.text()).toContain('GitLab Credits');
        expect(wrapper.text()).toContain('Save with monthly commitments');
        expect(wrapper.text()).toContain(
          'Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
        );
      });

      it('does not display default title and description', () => {
        expect(wrapper.text()).not.toContain('Buy Credits');
        expect(wrapper.text()).not.toContain('GitLab Duo Agent Platform');
      });

      it('renders purchase credits button with correct attributes', () => {
        const button = findPurchaseCreditsLink();
        expect(button.exists()).toBe(true);
        expect(button.attributes('href')).toBe(selfManagedPurchaseCreditsPath);
        expect(button.attributes('target')).toBe('_blank');
        expect(button.attributes('rel')).toBe('noopener noreferrer');
        expect(button.text()).toBe('Purchase credits');
      });

      it('does not render learn more button', () => {
        expect(findLearnMoreLink().exists()).toBe(false);
      });

      it('does not render HandRaiseLeadButton', () => {
        expect(findHandRaiseLeadButton().exists()).toBe(false);
      });

      it('does not render talk to sales link', () => {
        expect(findTalkToSalesLink().exists()).toBe(false);
      });
    });

    describe('when on Self-Managed with showSmPurchaseButton but no selfManagedPurchaseCreditsPath', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false, showSmPurchaseButton: true });
      });

      it('falls back to talk to sales', () => {
        expect(findTalkToSalesLink().exists()).toBe(true);
        expect(findPurchaseCreditsLink().exists()).toBe(false);
      });

      it('displays monthly commitment title and description', () => {
        expect(wrapper.text()).toContain('GitLab Credits');
        expect(wrapper.text()).toContain('Save with monthly commitments');
        expect(wrapper.text()).toContain(
          'Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
        );
      });
    });

    describe('when on Self-Managed with selfManagedPurchaseCreditsPath but no showSmPurchaseButton', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false, selfManagedPurchaseCreditsPath });
      });

      it('falls back to talk to sales', () => {
        expect(findTalkToSalesLink().exists()).toBe(true);
        expect(findPurchaseCreditsLink().exists()).toBe(false);
      });

      it('displays default title and description', () => {
        expect(wrapper.text()).toContain('Buy Credits');
        expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
      });
    });

    describe('when on Self-Managed with isSmTrial alone (no showSmPurchaseButton)', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false, isSmTrial: true, showSmPurchaseButton: false });
      });

      it('does not display monthly commitment title and description', () => {
        expect(wrapper.text()).not.toContain('GitLab Credits');
        expect(wrapper.text()).not.toContain('Save with monthly commitments');
      });

      it('displays default title and description', () => {
        expect(wrapper.text()).toContain('Buy Credits');
        expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
      });

      it('renders talk to sales link', () => {
        expect(findTalkToSalesLink().exists()).toBe(true);
      });

      it('does not render purchase credits button', () => {
        expect(findPurchaseCreditsLink().exists()).toBe(false);
      });
    });

    describe('when creditsGeneralizationUi is enabled', () => {
      describe('on SaaS with gitlabComPurchaseCreditsPath provided', () => {
        beforeEach(() => {
          createComponent({
            isSaaS: true,
            gitlabComPurchaseCreditsPath,
            creditsGeneralizationUi: true,
          });
        });

        it('displays credits generalized title', () => {
          expect(wrapper.text()).toContain('Buy GitLab Credits');
        });

        it('does not display subtitle', () => {
          expect(wrapper.text()).not.toContain('Save with monthly commitments');
          expect(wrapper.text()).not.toContain('GitLab Duo Agent Platform');
        });

        it('displays credits generalized description', () => {
          expect(wrapper.text()).toContain(
            'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
          );
        });

        it('renders purchase credits button in the header', () => {
          const button = findPurchaseCreditsLink();
          expect(button.exists()).toBe(true);
          expect(button.attributes('href')).toBe(gitlabComPurchaseCreditsPath);
          expect(button.attributes('size')).toBe('small');
        });

        it('renders learn more as inline link in the body', () => {
          const link = wrapper.findComponent(GlLink);
          expect(link.exists()).toBe(true);
          expect(link.attributes('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
          expect(link.text()).toBe('Learn more');
        });

        it('does not render footer content', () => {
          expect(findCardFooter().exists()).toBe(false);
          expect(findFooterPurchaseCreditsLink().exists()).toBe(false);
        });

        it('does not render the hand raise lead button', () => {
          expect(findHandRaiseLeadButton().exists()).toBe(false);
        });

        it('does not render the talk to sales link', () => {
          expect(findTalkToSalesLink().exists()).toBe(false);
        });
      });

      describe('on Self-Managed without showSmPurchaseButton (showMonthlyCommitmentVariant is false)', () => {
        beforeEach(() => {
          createComponent({
            isSaaS: false,
            showSmPurchaseButton: false,
            creditsGeneralizationUi: true,
          });
        });

        it('displays old subtitle and description', () => {
          expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
          expect(wrapper.text()).toContain(
            'Orchestrate AI agents across your entire software lifecycle to automate complex workflows, accelerate delivery, and keep your team in flow',
          );
        });

        it('does not display credits generalized title', () => {
          expect(wrapper.text()).not.toContain('Buy GitLab Credits');
        });

        it('does not display credits generalized description', () => {
          expect(wrapper.text()).not.toContain('Credits from $1, with volume discounts.');
        });

        it('renders footer content with talk to sales', () => {
          expect(findCardFooter().exists()).toBe(true);
          expect(findTalkToSalesLink().exists()).toBe(true);
        });

        it('does not render purchase credits button in footer', () => {
          expect(findFooterPurchaseCreditsLink().exists()).toBe(false);
        });
      });

      describe('on Self-Managed with showSmPurchaseButton and selfManagedPurchaseCreditsPath', () => {
        beforeEach(() => {
          createComponent({
            isSaaS: false,
            showSmPurchaseButton: true,
            selfManagedPurchaseCreditsPath,
            creditsGeneralizationUi: true,
          });
        });

        it('displays credits generalized title', () => {
          expect(wrapper.text()).toContain('Buy GitLab Credits');
        });

        it('does not display subtitle', () => {
          expect(wrapper.text()).not.toContain('Save with monthly commitments');
          expect(wrapper.text()).not.toContain('GitLab Duo Agent Platform');
        });

        it('displays credits generalized description', () => {
          expect(wrapper.text()).toContain(
            'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
          );
        });

        it('renders purchase credits button in the header', () => {
          const button = findPurchaseCreditsLink();
          expect(button.exists()).toBe(true);
          expect(button.attributes('href')).toBe(selfManagedPurchaseCreditsPath);
          expect(button.attributes('size')).toBe('small');
        });

        it('renders learn more as inline link in the body', () => {
          const link = wrapper.findComponent(GlLink);
          expect(link.exists()).toBe(true);
          expect(link.text()).toBe('Learn more');
        });

        it('does not render footer content', () => {
          expect(findCardFooter().exists()).toBe(false);
          expect(findFooterPurchaseCreditsLink().exists()).toBe(false);
        });

        it('does not render the hand raise lead button', () => {
          expect(findHandRaiseLeadButton().exists()).toBe(false);
        });

        it('does not render the talk to sales link', () => {
          expect(findTalkToSalesLink().exists()).toBe(false);
        });
      });
    });

    describe('when on SaaS and gitlabComPurchaseCreditsPath provided', () => {
      beforeEach(() => {
        createComponent({
          isSaaS: true,
          gitlabComPurchaseCreditsPath,
        });
      });

      it('displays monthly commitment title and description', () => {
        expect(wrapper.text()).toContain('GitLab Credits');
        expect(wrapper.text()).toContain('Save with monthly commitments');
        expect(wrapper.text()).toContain(
          'Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
        );
      });

      it('does not display default title and description', () => {
        expect(wrapper.text()).not.toContain('Buy Credits');
        expect(wrapper.text()).not.toContain('GitLab Duo Agent Platform');
      });

      it('renders purchase credits button with correct attributes', () => {
        const button = findPurchaseCreditsLink();
        expect(button.exists()).toBe(true);
        expect(button.attributes('href')).toBe(gitlabComPurchaseCreditsPath);
        expect(button.attributes('target')).toBe('_blank');
        expect(button.attributes('rel')).toBe('noopener noreferrer');
        expect(button.text()).toBe('Purchase credits');
      });

      it('renders learn more button', () => {
        const button = findLearnMoreLink();
        expect(button.attributes('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
        expect(button.attributes('target')).toBe('_blank');
        expect(button.attributes('rel')).toBe('noopener noreferrer');
        expect(button.text()).toBe('Learn more');
      });

      it('does not render HandRaiseLeadButton', () => {
        expect(findHandRaiseLeadButton().exists()).toBe(false);
      });

      it('does not render talk to sales link', () => {
        expect(findTalkToSalesLink().exists()).toBe(false);
      });

      describe('when on SaaS with gitlab credits', () => {
        beforeEach(() => {
          createComponent({
            isSaaS: true,
            gitlabComPurchaseCreditsPath,
            hasGitlabCredits: true,
          });
        });

        it('renders purchase credits button with "Increase credits" text', () => {
          expect(findPurchaseCreditsLink().text()).toBe('Increase credits');
        });

        it('renders learn more button with correct attributes', () => {
          const button = findLearnMoreLink();
          expect(button.attributes('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
          expect(button.attributes('target')).toBe('_blank');
          expect(button.attributes('rel')).toBe('noopener noreferrer');
          expect(button.text()).toBe('Learn more');
        });

        it('does not render HandRaiseLeadButton', () => {
          expect(findHandRaiseLeadButton().exists()).toBe(false);
        });

        it('does not render direct link button', () => {
          expect(findTalkToSalesLink().exists()).toBe(false);
        });
      });
    });
  });

  describe('tracking', () => {
    let trackingSpy;
    const glIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    describe('when on Self-Managed', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('tracks page view on load', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_agent_platform_buy_credits_card',
        });
      });

      it('tracks button click event', async () => {
        await findTalkToSalesLink().vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
          label: 'duo_agent_platform_talk_to_sales',
        });
      });
    });

    describe('when on SaaS', () => {
      beforeEach(() => {
        createComponent({ isSaaS: true });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('tracks page view on load', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_agent_platform_buy_credits_card',
        });
      });

      it('passes tracking configuration to HandRaiseLeadButton', () => {
        const handRaiseButton = findHandRaiseLeadButton();
        expect(handRaiseButton.props('ctaTracking')).toEqual({
          action: 'click_button',
          label: 'duo_agent_platform_buy_credits_card_talk_to_sales',
        });
      });
    });

    describe('when on SaaS with trial and gitlabComPurchaseCreditsPath provided', () => {
      beforeEach(() => {
        createComponent({
          isSaaS: true,
          gitlabComPurchaseCreditsPath,
        });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('tracks page view on load', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_agent_platform_buy_credits_card',
        });
      });

      describe('purchaseCreditsEventTracking', () => {
        it.each`
          hasGitlabCredits | namespaceIsOnTrial | expected
          ${false}         | ${false}           | ${'click_purchase_credits_cta'}
          ${false}         | ${true}            | ${'click_purchase_credits_cta_active_trial'}
          ${true}          | ${false}           | ${'click_increase_credits_cta'}
          ${true}          | ${true}            | ${'click_increase_credits_cta_active_trial'}
        `(
          'returns "$expected" when hasGitlabCredits=$hasGitlabCredits and namespaceIsOnTrial=$namespaceIsOnTrial',
          ({ hasGitlabCredits, namespaceIsOnTrial, expected }) => {
            createComponent({
              isSaaS: true,
              gitlabComPurchaseCreditsPath,
              hasGitlabCredits,
              namespaceIsOnTrial,
            });

            expect(findPurchaseCreditsLink().attributes('data-event-tracking')).toBe(expected);
          },
        );
      });
    });

    describe('when on Self-Managed with showSmPurchaseButton and selfManagedPurchaseCreditsPath provided', () => {
      beforeEach(() => {
        createComponent({
          isSaaS: false,
          showSmPurchaseButton: true,
          selfManagedPurchaseCreditsPath,
        });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('tracks page view on load', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_agent_platform_buy_credits_card',
        });
      });

      describe('purchaseCreditsEventTracking', () => {
        it.each`
          hasGitlabCredits | isSmTrial | expected
          ${false}         | ${true}   | ${'click_purchase_credits_cta_active_trial'}
          ${true}          | ${true}   | ${'click_increase_credits_cta_active_trial'}
          ${false}         | ${false}  | ${'click_purchase_credits_cta'}
          ${true}          | ${false}  | ${'click_increase_credits_cta'}
        `(
          'returns "$expected" when hasGitlabCredits=$hasGitlabCredits and isSmTrial=$isSmTrial',
          ({ hasGitlabCredits, isSmTrial, expected }) => {
            createComponent({
              isSaaS: false,
              showSmPurchaseButton: true,
              isSmTrial,
              selfManagedPurchaseCreditsPath,
              hasGitlabCredits,
            });

            expect(findPurchaseCreditsLink().attributes('data-event-tracking')).toBe(expected);
          },
        );
      });
    });
  });
});
