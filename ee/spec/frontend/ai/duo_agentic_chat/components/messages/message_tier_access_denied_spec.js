import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import MessageTierAccessDenied from 'ee/ai/duo_agentic_chat/components/messages/message_tier_access_denied.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

describe('MessageTierAccessDenied', () => {
  let wrapper;
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const TIER_UPGRADE_PATH = '/-/subscriptions/new?namespace_id=42';

  const defaultMessage = {
    message_type: 'agent',
    role: 'assistant',
    message_sub_type: 'tier_access_denied',
    content:
      'Listing epics requires a **GitLab Premium** subscription (or higher).\n\n[Learn more](https://docs.gitlab.com/user/duo_agent_platform/)',
    required_plan: 'premium',
  };

  const createComponent = ({
    message = defaultMessage,
    isHandRaiseLeadAvailable = false,
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(MessageTierAccessDenied, {
      propsData: { message, isHandRaiseLeadAvailable },
      provide: {
        canBuyAddon: true,
        tierUpgradePath: TIER_UPGRADE_PATH,
        ...provide,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findTalkToSalesButton = () => wrapper.findComponent(HandRaiseLeadButton);
  const findContainer = () => wrapper.findByTestId('tier-access-denied-message');
  const findContent = () => findContainer().find('div > div');

  describe('rendered content', () => {
    it('renders bold markdown', () => {
      createComponent();

      expect(findContent().html()).toContain('<strong>GitLab Premium</strong>');
    });

    it('renders links inline (collapses paragraph breaks) when upgrade button shows', () => {
      createComponent();

      expect(findContent().html()).toBe(
        '<div>\n  <p>Listing epics requires a <strong>GitLab Premium</strong> subscription (or higher). <a href="https://docs.gitlab.com/user/duo_agent_platform/">Learn more</a></p>\n</div>',
      );
    });

    it('preserves paragraph breaks when upgrade button is hidden', () => {
      createComponent({ provide: { canBuyAddon: false } });

      expect(findContent().html()).toBe(
        '<div>\n  <p>Listing epics requires a <strong>GitLab Premium</strong> subscription (or higher).</p>\n  <p><a href="https://docs.gitlab.com/user/duo_agent_platform/">Learn more</a></p>\n</div>',
      );
    });

    it('renders no content div when content is missing', () => {
      const { content: _ignored, ...messageNoContent } = defaultMessage;
      createComponent({ message: messageNoContent });

      expect(findContent().exists()).toBe(false);
    });
  });

  describe('upgrade button', () => {
    it('renders for owner with required_plan', () => {
      createComponent();

      const button = findButton();
      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Upgrade subscription');
    });

    it('appends plan_name=premium when required_plan is premium', () => {
      createComponent();

      expect(findButton().attributes('href')).toBe(`${TIER_UPGRADE_PATH}&plan_name=premium`);
    });

    it('appends plan_name=ultimate when required_plan is ultimate', () => {
      createComponent({ message: { ...defaultMessage, required_plan: 'ultimate' } });

      expect(findButton().attributes('href')).toBe(`${TIER_UPGRADE_PATH}&plan_name=ultimate`);
    });

    it('opens in a new tab', () => {
      createComponent();

      expect(findButton().attributes('target')).toBe('_blank');
    });

    it('does not render when user is not group owner', () => {
      createComponent({ provide: { canBuyAddon: false } });

      expect(findButton().exists()).toBe(false);
    });

    it('falls back to plan_name=ultimate when required_plan is missing', () => {
      const { required_plan: _ignored, ...messageNoPlan } = defaultMessage;
      createComponent({ message: messageNoPlan });

      expect(findButton().attributes('href')).toBe(`${TIER_UPGRADE_PATH}&plan_name=ultimate`);
    });

    it('does not render the "Talk to sales" CTA for non-credits owners', () => {
      createComponent();

      expect(findTalkToSalesButton().exists()).toBe(false);
    });
  });

  describe('talk to sales button (free namespace with GitLab credits add-on)', () => {
    const createForCreditsUser = (overrides = {}) =>
      createComponent({ isHandRaiseLeadAvailable: true, ...overrides });

    it('renders the hand raise lead button instead of the upgrade button', () => {
      createForCreditsUser();

      expect(findTalkToSalesButton().exists()).toBe(true);
      expect(findTalkToSalesButton().props('buttonText')).toBe('Talk to sales');
      expect(findButton().exists()).toBe(false);
    });

    it('passes the glm content and cta tracking that identify the trigger', () => {
      createForCreditsUser();

      expect(findTalkToSalesButton().props('glmContent')).toBe(
        'gitlab-duo-chat-tier-access-denied',
      );
      expect(findTalkToSalesButton().props('ctaTracking')).toEqual({
        action: 'click_button',
        label: 'duo_chat_tier_access_denied_talk_to_sales',
      });
    });

    it('does not render when hand raise lead data is not available', () => {
      createForCreditsUser({ isHandRaiseLeadAvailable: false });

      expect(findTalkToSalesButton().exists()).toBe(false);
    });

    it('collapses paragraph breaks when the CTA is the hand raise lead button, even without buy-addon access', () => {
      createForCreditsUser({ provide: { canBuyAddon: false } });

      expect(findContent().html()).toBe(
        '<div>\n  <p>Listing epics requires a <strong>GitLab Premium</strong> subscription (or higher). <a href="https://docs.gitlab.com/user/duo_agent_platform/">Learn more</a></p>\n</div>',
      );
    });
  });

  describe('tracking', () => {
    it.each([
      ['premium', 'premium_plan'],
      ['ultimate', 'ultimate_plan'],
      [null, 'unknown_plan'],
      ['weird-plan', 'unknown_plan'],
    ])('tracks upgrade click with label "%s" → "%s"', async (requiredPlan, expectedLabel) => {
      const { required_plan: _ignored, ...rest } = defaultMessage;
      const message = requiredPlan ? { ...rest, required_plan: requiredPlan } : rest;
      createComponent({ message });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_upgrade_subscription_duo_chat_tier_access_denied',
        { label: expectedLabel },
        undefined,
      );
    });

    it('tracks learn more click when an anchor inside the content is clicked', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      const anchor = findContent().element.querySelector('a');
      expect(anchor).not.toBeNull();
      anchor.addEventListener('click', (e) => e.preventDefault());
      anchor.click();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_more_duo_chat_tier_access_denied',
        {},
        undefined,
      );
    });

    it('does not track learn more click when non-anchor content is clicked', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      const strong = findContent().element.querySelector('strong');
      expect(strong).not.toBeNull();
      strong.click();

      expect(trackEventSpy).not.toHaveBeenCalledWith(
        'click_learn_more_duo_chat_tier_access_denied',
        expect.anything(),
        expect.anything(),
      );
    });

    it('tracks learn more click regardless of the anchor label so tracking survives translation', () => {
      createComponent({
        message: {
          ...defaultMessage,
          content:
            'Upgrade required. [En savoir plus](https://docs.gitlab.com/user/duo_agent_platform/)',
        },
      });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      const anchor = findContent().element.querySelector('a');
      expect(anchor).not.toBeNull();
      anchor.addEventListener('click', (e) => e.preventDefault());
      anchor.click();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_more_duo_chat_tier_access_denied',
        {},
        undefined,
      );
    });
  });
});
