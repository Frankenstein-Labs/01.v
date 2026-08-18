import { GlIcon, GlPopover, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import FeatureItem from 'ee/groups/discover/components/feature_item.vue';

describe('FeatureItem', () => {
  let wrapper;

  const defaultProps = {
    id: 'feature-1',
    text: 'Feature Name',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findFeatureButton = () => wrapper.findByRole('button');
  const findLink = () => wrapper.findComponent(GlButton);

  describe('without description', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders check icon', () => {
      expect(findIcon().props('name')).toBe('check');
      expect(findIcon().props('size')).toBe(16);
    });

    it('renders plain text', () => {
      expect(wrapper.text()).toContain('Feature Name');
    });

    it('does not render popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('with description', () => {
    beforeEach(() => {
      createComponent({ props: { description: 'Feature description' } });
    });

    it('renders clickable feature text', () => {
      expect(findFeatureButton().exists()).toBe(true);
      expect(findFeatureButton().text()).toBe('Feature Name');
    });

    it('renders popover', () => {
      expect(findPopover().props()).toMatchObject({
        target: 'feature-1',
        placement: 'top',
        triggers: 'manual',
        showCloseButton: true,
        show: false,
      });
    });
  });

  describe('popover state', () => {
    it('shows popover when openPopoverId matches id', () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'feature-1',
        },
      });

      expect(findPopover().props('show')).toBe(true);
      expect(findFeatureButton().attributes('aria-expanded')).toBe('true');
    });

    it('hides popover when openPopoverId does not match', () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'other-feature',
        },
      });

      expect(findPopover().props('show')).toBe(false);
      expect(findFeatureButton().attributes('aria-expanded')).toBe('false');
    });
  });

  describe('link', () => {
    it('renders link when provided', () => {
      createComponent({
        props: {
          description: 'Feature description',
          link: 'https://example.com',
        },
      });

      expect(findLink().attributes()).toMatchObject({
        href: 'https://example.com',
        target: '_blank',
        rel: 'noopener noreferrer',
      });
    });

    it('does not render link when not provided', () => {
      createComponent({
        props: { description: 'Feature description' },
      });

      expect(findLink().exists()).toBe(false);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent({ props: { description: 'Feature description' } });
    });

    it('emits popover-toggle event when feature text is clicked', async () => {
      await findFeatureButton().trigger('click');

      expect(wrapper.emitted('popover-toggle')).toEqual([['feature-1']]);
    });

    it('emits popover-toggle when popover close button is clicked', async () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'feature-1',
        },
      });

      await findPopover().vm.$emit('hidden');

      expect(wrapper.emitted('popover-toggle')).toEqual([['feature-1']]);
    });

    it('does not emit popover-toggle when hidden event fires but popover is not open', async () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'other-feature',
        },
      });

      await findPopover().vm.$emit('hidden');

      expect(wrapper.emitted('popover-toggle')).toBeUndefined();
    });

    it('does not emit duplicate events when switching between popovers', async () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'feature-1',
        },
      });

      // Simulate closing the popover
      await findPopover().vm.$emit('hidden');

      expect(wrapper.emitted('popover-toggle')).toEqual([['feature-1']]);
    });
  });

  describe('popover close button', () => {
    it('renders close button on popover', () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'feature-1',
        },
      });

      expect(findPopover().props('showCloseButton')).toBe(true);
    });

    it('closes popover after close button is clicked', async () => {
      createComponent({
        props: {
          description: 'Feature description',
          openPopoverId: 'feature-1',
        },
      });

      await findPopover().vm.$emit('hidden');
      await wrapper.setProps({ openPopoverId: null });

      expect(findPopover().props('show')).toBe(false);
      expect(findFeatureButton().attributes('aria-expanded')).toBe('false');
    });
  });

  describe('accessibility', () => {
    beforeEach(() => {
      createComponent({ props: { description: 'Feature description' } });
    });

    it('has proper aria attributes for button', () => {
      expect(findFeatureButton().attributes()).toMatchObject({
        'aria-expanded': 'false',
        'aria-controls': 'popover-feature-1',
      });
    });

    it('updates aria-expanded when popover opens', async () => {
      await wrapper.setProps({ openPopoverId: 'feature-1' });

      expect(findFeatureButton().attributes('aria-expanded')).toBe('true');
    });
  });

  describe('tracking', () => {
    let trackingSpy;
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent({
        props: {
          description: 'Feature description',
          link: 'https://example.com',
        },
      });
      trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
      trackingSpy.mockClear();
    });

    it('tracks popover show event when popover is shown', async () => {
      await findPopover().vm.$emit('shown');

      expect(trackingSpy).toHaveBeenCalledWith(
        'render_premium_feature_popover_discover',
        { property: 'feature-1' },
        undefined,
      );
    });

    it('tracks popover click event when learn more button is clicked', async () => {
      await findLink().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_cta_premium_feature_popover_discover',
        { property: 'feature-1' },
        undefined,
      );
    });
  });
});
