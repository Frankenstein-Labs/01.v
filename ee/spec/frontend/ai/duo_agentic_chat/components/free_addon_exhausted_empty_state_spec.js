import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import FreeAddonExhaustedEmptyState from 'ee/ai/duo_agentic_chat/components/free_addon_exhausted_empty_state.vue';
import TanukiAiIcon from 'ee/ai/shared/widgets/tanuki_ai_icon.vue';

describe('FreeAddonExhaustedEmptyState', () => {
  let wrapper;

  const defaultProps = {
    purchaseCreditsPath: '/purchase/credits',
    canBuyAddon: true,
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FreeAddonExhaustedEmptyState, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findContainer = () => wrapper.findByTestId('free-addon-exhausted-empty-state');
  const findTanukiAiIcon = () => wrapper.findComponent(TanukiAiIcon);
  const findHeading = () => wrapper.find('h2');
  const findDescription = () => wrapper.find('p');
  const findLearnMoreButton = () => wrapper.findComponentByTestId('learn-more-button');
  const findPrimaryCta = () => wrapper.findComponentByTestId('primary-cta');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the container and icon', () => {
      expect(findContainer().exists()).toBe(true);
      expect(findTanukiAiIcon().exists()).toBe(true);
    });

    it('renders the correct headline', () => {
      expect(findHeading().text()).toBe('No credits remaining');
    });

    it('renders the correct description', () => {
      expect(findDescription().text()).toContain('purchase more credits');
    });

    it('always renders the learn more button linking to DAP docs', () => {
      expect(findLearnMoreButton().exists()).toBe(true);
      expect(findLearnMoreButton().attributes('href')).toContain('duo_agent_platform');
    });
  });

  describe('primary CTA visibility', () => {
    it('shows the primary CTA when canBuyAddon is true and purchaseCreditsPath is provided', () => {
      createComponent({ canBuyAddon: true, purchaseCreditsPath: '/purchase/credits' });

      expect(findPrimaryCta().exists()).toBe(true);
      expect(findPrimaryCta().attributes('href')).toBe('/purchase/credits');
      expect(findPrimaryCta().text()).toBe('Purchase credits');
    });

    it('hides the primary CTA when canBuyAddon is false', () => {
      createComponent({ canBuyAddon: false });

      expect(findPrimaryCta().exists()).toBe(false);
    });

    it('hides the primary CTA when purchaseCreditsPath is empty', () => {
      createComponent({ canBuyAddon: true, purchaseCreditsPath: '' });

      expect(findPrimaryCta().exists()).toBe(false);
    });
  });

  describe('tracking', () => {
    describe('view event', () => {
      it('tracks view event with free_addon label on mount', () => {
        createComponent();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'free_addon' },
          undefined,
        );
      });
    });

    describe('click events', () => {
      it('tracks learn more click with free_addon label', async () => {
        createComponent();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findLearnMoreButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_learn_more',
          { label: 'free_addon' },
          undefined,
        );
      });

      it('tracks purchase credits click with free_addon label', async () => {
        createComponent({ canBuyAddon: true, purchaseCreditsPath: '/purchase/credits' });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findPrimaryCta().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_purchase_credits',
          { label: 'free_addon' },
          undefined,
        );
      });
    });
  });
});
