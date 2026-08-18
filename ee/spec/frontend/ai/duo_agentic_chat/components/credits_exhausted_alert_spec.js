import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import CreditsExhaustedAlert from 'ee/ai/duo_agentic_chat/components/credits_exhausted_alert.vue';

describe('CreditsExhaustedAlert', () => {
  let wrapper;

  const defaultProps = {
    purchaseCreditsPath: '/purchase/credits',
    canBuyAddon: true,
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(CreditsExhaustedAlert, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlAlert },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDescription = () => wrapper.find('p');
  const findLearnMoreButton = () => wrapper.findComponentByTestId('learn-more-button');
  const findPrimaryCta = () => wrapper.findComponentByTestId('primary-cta');

  describe('rendering', () => {
    describe('when isTrial is true', () => {
      beforeEach(() => {
        createComponent({ isTrial: true });
      });

      it('renders a non-dismissible warning alert', () => {
        expect(findAlert().props('variant')).toBe('warning');
        expect(findAlert().props('dismissible')).toBe(false);
      });

      it('renders the trial title', () => {
        expect(findAlert().props('title')).toBe('No credits remaining');
      });
    });

    describe('when isTrial is false', () => {
      beforeEach(() => {
        createComponent({ isTrial: false });
      });

      it('renders the paid title', () => {
        expect(findAlert().props('title')).toBe('No credits remain for this billing period');
      });
    });

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

    describe('when isFreeAddonCreditsUser is true', () => {
      beforeEach(() => {
        createComponent({ isFreeAddonCreditsUser: true });
      });

      it('renders the free addon title', () => {
        expect(findAlert().props('title')).toBe('No credits remaining');
      });

      it('renders the free addon description without agentic toggle mention', () => {
        expect(findDescription().text()).toContain('purchase more credits');
        expect(findDescription().text()).not.toContain('Agentic toggle');
      });
    });

    it('always renders the learn more button linking to DAP docs', () => {
      createComponent();

      expect(findLearnMoreButton().exists()).toBe(true);
      expect(findLearnMoreButton().attributes('href')).toContain('duo_agent_platform');
    });
  });

  describe('primary CTA visibility', () => {
    it('shows the primary CTA when canBuyAddon is true and purchaseCreditsPath is provided', () => {
      createComponent({
        isTrial: false,
        canBuyAddon: true,
        purchaseCreditsPath: '/purchase/credits',
      });

      expect(findPrimaryCta().exists()).toBe(true);
      expect(findPrimaryCta().attributes('href')).toBe('/purchase/credits');
      expect(findPrimaryCta().text()).toBe('Purchase more credits');
    });

    it('shows trial CTA text when isTrial is true', () => {
      createComponent({
        isTrial: true,
        canBuyAddon: true,
        purchaseCreditsPath: '/purchase/credits',
      });

      expect(findPrimaryCta().text()).toBe('Purchase credits');
    });

    it('shows "Purchase more credits" CTA for free addon users', () => {
      createComponent({
        isFreeAddonCreditsUser: true,
        canBuyAddon: true,
        purchaseCreditsPath: '/purchase/credits',
      });

      expect(findPrimaryCta().text()).toBe('Purchase more credits');
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
      it('tracks view event with paid label on mount', () => {
        createComponent({ isTrial: false });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks view event with trial label on mount', () => {
        createComponent({ isTrial: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'trial' },
          undefined,
        );
      });

      it('tracks view event with free_addon label on mount', () => {
        createComponent({ isFreeAddonCreditsUser: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'free_addon' },
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

      it('tracks purchase credits click with trial label', async () => {
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

      it('tracks purchase credits click with paid label', async () => {
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
    });
  });
});
