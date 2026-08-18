import { GlEmptyState, GlIntersectionObserver, GlSprintf } from '@gitlab/ui';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import SubscriptionActivationModal from 'ee/admin/subscriptions/show/components/subscription_activation_modal.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mockHandRaiseLeadData } from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { subscriptionTypes } from 'ee/admin/subscriptions/show/constants';
import { VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD } from 'ee/usage_quotas/code_suggestions/constants';

describe('Code Suggestions Intro', () => {
  let wrapper;

  const emptyState = () => wrapper.findComponent(GlEmptyState);
  const handRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);
  const findActivationModal = () => wrapper.findComponent(SubscriptionActivationModal);
  const learnMoreLink = () => wrapper.findComponentByTestId('duo-pro-learn-more-link');
  const trialBtn = () => wrapper.findComponentByTestId('duo-pro-start-trial-btn');
  const purchaseSeatsBtn = () => wrapper.findComponentByTestId('duo-pro-purchase-seats-btn');
  const buySubscriptionBtn = () => wrapper.findComponentByTestId('duo-pro-buy-subscription-btn');
  const postTrialAlert = () => wrapper.findByTestId('duo-pro-post-trial-alert');

  const addActivationCodeBtn = () =>
    wrapper.findByTestId('code-suggestions-activate-subscription-action');

  const findSubscriptionActivationSuccessAlert = () =>
    wrapper.findByTestId('subscription-activation-success-alert');

  const createComponent = ({ props = {}, provideProps = {} } = {}) => {
    wrapper = shallowMountExtended(CodeSuggestionsIntro, {
      mocks: { GlEmptyState },
      stubs: { GlSprintf },
      propsData: { subscription: {}, ...props },
      provide: {
        ...provideProps,
        handRaiseLeadData: mockHandRaiseLeadData,
      },
    });
  };

  describe('on page load', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD event', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD,
        {},
        undefined,
      );
    });
  });

  describe('when rendering', () => {
    it('renders gl-empty-state component with hand raise lead', () => {
      createComponent();

      const buttonProps = {
        ...mockHandRaiseLeadData,
        buttonText: 'Contact sales',
      };

      expect(emptyState().exists()).toBe(true);
      expect(handRaiseLeadButton().exists()).toBe(true);
      expect(handRaiseLeadButton().props()).toEqual(buttonProps);
    });

    it('renders title and description', () => {
      createComponent();

      expect(wrapper.text()).toContain('Introducing GitLab Duo');

      expect(wrapper.text()).toContain(
        'Enhance your coding experience with intelligent recommendations. GitLab Duo offers features that use generative AI to suggest code.',
      );
    });

    it('renders post trial experience for free namespace', () => {
      createComponent({ provideProps: { isFreeNamespace: true } });

      expect(postTrialAlert().exists()).toBe(true);
      expect(wrapper.text()).toContain(
        wrapper.vm.$options.i18n.postTrialForFreeNamespaceDescription,
      );
    });
  });

  describe('with CTA buttons', () => {
    it('renders trial button as primary button when duo pro trial href is present', () => {
      createComponent({ provideProps: { duoProTrialHref: 'some-path' } });

      expect(addActivationCodeBtn().exists()).toBe(false);
      expect(buySubscriptionBtn().exists()).toBe(false);
      expect(trialBtn().attributes('category')).toEqual('primary');
      expect(purchaseSeatsBtn().attributes('category')).toEqual('secondary');
    });

    it('does not render trial button, render purchase seats button as primary button when duo pro trial href is missing', () => {
      createComponent();

      expect(addActivationCodeBtn().exists()).toBe(false);
      expect(buySubscriptionBtn().exists()).toBe(false);
      expect(trialBtn().exists()).toBe(false);
      expect(purchaseSeatsBtn().attributes('category')).toEqual('primary');
    });

    it('renders buy subscription button when showing the post trial experience for free namespace', () => {
      createComponent({ provideProps: { isFreeNamespace: true } });

      expect(addActivationCodeBtn().exists()).toBe(false);
      expect(buySubscriptionBtn().exists()).toBe(true);
      expect(trialBtn().exists()).toBe(false);
      expect(purchaseSeatsBtn().exists()).toBe(false);
    });
  });

  describe('with tracking', () => {
    let trackingSpy;
    const glIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    beforeEach(() => {
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent({ provideProps: { duoProTrialHref: 'some-path' } });
    });

    describe('with duo pro tab page view tracking', () => {
      it('tracks when duo pro trial href is present', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_pro_add_on_tab_pre_trial',
        });
      });

      it('tracks when trial expired for free namespace', () => {
        createComponent({ provideProps: { isFreeNamespace: true } });

        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_pro_add_on_tab_expired_trial',
        });
      });

      it('does not track when duo pro trial href is missing', () => {
        createComponent();
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).not.toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_pro_add_on_tab_pre_trial',
        });
      });
    });

    it('tracks when duo pro learn more link is clicked', () => {
      learnMoreLink().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_link', {
        label: 'duo_pro_marketing_page',
      });
    });

    it('tracks when duo pro start trial button is clicked', () => {
      trialBtn().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'duo_pro_start_trial',
      });
    });

    it('tracks when duo pro purchase seats button is clicked', () => {
      purchaseSeatsBtn().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'duo_pro_purchase_seats',
      });
    });

    it('tracks when duo pro buy subscription button is clicked', () => {
      createComponent({ provideProps: { isFreeNamespace: true } });

      buySubscriptionBtn().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'duo_pro_buy_subscription',
      });
    });
  });

  describe('when saas with legacy subscription', () => {
    beforeEach(() => {
      createComponent({ props: { subscription: { type: subscriptionTypes.LEGACY_LICENSE } } });
    });

    it('does not render add activation code button as primary button', () => {
      expect(addActivationCodeBtn().exists()).toBe(false);
    });

    it('does not render activation modal', () => {
      expect(findActivationModal().exists()).toBe(false);
    });
  });

  describe('when self-managed without legacy subscription', () => {
    beforeEach(() => {
      createComponent({ provideProps: { isSaaS: false } });
    });

    it('does not render add activation code button as primary button', () => {
      expect(addActivationCodeBtn().exists()).toBe(false);
    });

    it('does not render activation modal', () => {
      expect(findActivationModal().exists()).toBe(false);
    });
  });

  describe('when self-managed with legacy subscription', () => {
    beforeEach(() => {
      createComponent({
        props: { subscription: { type: subscriptionTypes.LEGACY_LICENSE } },
        provideProps: { isSaaS: false },
      });
    });

    it('renders title and description', () => {
      expect(wrapper.text()).toContain('Subscription not synchronized');

      expect(wrapper.text()).toContain(
        'GitLab Duo is only available to instances with a synchronized subscription. Add an activation code to synchronize your subscription.',
      );
    });

    it('renders add activation code button as primary button', () => {
      expect(addActivationCodeBtn().attributes('category')).toEqual('primary');
    });

    it('renders activation modal', () => {
      expect(findActivationModal().exists()).toBe(true);
      expect(buySubscriptionBtn().exists()).toBe(false);
      expect(trialBtn().exists()).toBe(false);
      expect(purchaseSeatsBtn().exists()).toBe(false);
    });

    it('does not render the hand raise lead', () => {
      expect(handRaiseLeadButton().exists()).toBe(false);
    });

    it('does not render the activation success notification', () => {
      expect(findSubscriptionActivationSuccessAlert().exists()).toBe(false);
    });
  });
});
