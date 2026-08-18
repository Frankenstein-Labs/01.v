import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import NoCreditsEmptyState from 'ee/ai/duo_agentic_chat/components/no_credits_empty_state.vue';
import TanukiAiIcon from 'ee/ai/shared/widgets/tanuki_ai_icon.vue';

describe('NoCreditsEmptyState', () => {
  let wrapper;

  const defaultProps = {
    isTrial: false,
    purchaseCreditsPath: '/purchase/credits',
    canBuyAddon: true,
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(NoCreditsEmptyState, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findContainer = () => wrapper.findByTestId('no-credits-empty-state');
  const findImage = () => wrapper.findComponent(TanukiAiIcon);
  const findHeading = () => wrapper.find('h2');
  const findDescription = () => wrapper.find('p');
  const findLearnMoreButton = () => wrapper.findComponentByTestId('learn-more-button');
  const findPrimaryCta = () => wrapper.findComponentByTestId('primary-cta');

  describe('rendering', () => {
    it('renders the container and image', () => {
      createComponent();

      expect(findContainer().exists()).toBe(true);
      expect(findImage().exists()).toBe(true);
    });

    it('always renders learn more button', () => {
      createComponent();

      expect(findLearnMoreButton().exists()).toBe(true);
      expect(findLearnMoreButton().attributes('href')).toContain('duo_agent_platform');
    });
  });

  describe('headline', () => {
    it('shows paid headline when isTrial is false', () => {
      createComponent({ isTrial: false });

      expect(findHeading().text()).toBe('No credits remain for this billing period');
    });

    it('shows trial headline when isTrial is true', () => {
      createComponent({ isTrial: true });

      expect(findHeading().text()).toBe('No credits remaining');
    });
  });

  describe('description', () => {
    describe('when hasAgenticToggle is true and isTrial is true', () => {
      beforeEach(() => {
        createComponent({ hasAgenticToggle: true, isTrial: true });
      });

      it('renders description with toggle mention and "Purchase credits"', () => {
        expect(findDescription().text()).toContain(
          'Purchase credits or turn off the Agentic toggle',
        );
      });
    });

    describe('when hasAgenticToggle is true and isTrial is false', () => {
      beforeEach(() => {
        createComponent({ hasAgenticToggle: true, isTrial: false });
      });

      it('renders description with toggle mention and "Purchase more credits"', () => {
        expect(findDescription().text()).toContain(
          'Purchase more credits or turn off the Agentic toggle',
        );
      });
    });

    describe('when hasAgenticToggle is false and isTrial is true', () => {
      beforeEach(() => {
        createComponent({ hasAgenticToggle: false, isTrial: true });
      });

      it('renders description without toggle mention and with "purchase credits"', () => {
        expect(findDescription().text()).toContain('purchase credits');
        expect(findDescription().text()).not.toContain('Agentic toggle');
        expect(findDescription().text()).not.toContain('purchase more credits');
      });
    });

    describe('when hasAgenticToggle is false and isTrial is false', () => {
      beforeEach(() => {
        createComponent({ hasAgenticToggle: false, isTrial: false });
      });

      it('renders description without toggle mention and with "purchase more credits"', () => {
        expect(findDescription().text()).toContain('purchase more credits');
        expect(findDescription().text()).not.toContain('Agentic toggle');
      });
    });
  });

  describe('primary CTA text', () => {
    it('shows "Purchase more credits" for paid users', () => {
      createComponent({ isTrial: false, purchaseCreditsPath: '/purchase/credits' });

      expect(findPrimaryCta().text()).toBe('Purchase more credits');
    });

    it('shows "Purchase credits" for trial users', () => {
      createComponent({ isTrial: true, purchaseCreditsPath: '/purchase/credits' });

      expect(findPrimaryCta().text()).toBe('Purchase credits');
    });
  });

  describe('CTA visibility', () => {
    it('shows primary CTA using purchaseCreditsPath', () => {
      createComponent({ canBuyAddon: true, purchaseCreditsPath: '/purchase/credits' });

      expect(findPrimaryCta().exists()).toBe(true);
      expect(findPrimaryCta().attributes('href')).toBe('/purchase/credits');
    });

    it('hides primary CTA when user cannot buy addon', () => {
      createComponent({ canBuyAddon: false });

      expect(findPrimaryCta().exists()).toBe(false);
    });

    it('hides primary CTA when purchaseCreditsPath is empty', () => {
      createComponent({ canBuyAddon: true, purchaseCreditsPath: '' });

      expect(findPrimaryCta().exists()).toBe(false);
    });
  });

  describe('tracking', () => {
    describe('view event', () => {
      it('tracks view event with "paid" label for paid users', () => {
        createComponent({ isTrial: false });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks view event with "trial" label for trial users', () => {
        createComponent({ isTrial: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'trial' },
          undefined,
        );
      });
    });

    describe('click events', () => {
      it('tracks learn more click with paid label', async () => {
        createComponent({ isTrial: false });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findLearnMoreButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_learn_more',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks learn more click with trial label', async () => {
        createComponent({ isTrial: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findLearnMoreButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_learn_more',
          { label: 'trial' },
          undefined,
        );
      });

      it('tracks purchase credits click for paid users with paid label', async () => {
        createComponent({
          isTrial: false,
          canBuyAddon: true,
          purchaseCreditsPath: '/purchase/credits',
        });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findPrimaryCta().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_purchase_credits',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks purchase credits click for trial users with trial label', async () => {
        createComponent({
          isTrial: true,
          canBuyAddon: true,
          purchaseCreditsPath: '/purchase/credits',
        });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findPrimaryCta().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_purchase_credits',
          { label: 'trial' },
          undefined,
        );
      });
    });
  });
});
