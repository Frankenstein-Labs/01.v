import { GlIcon, GlBadge, GlButton, GlPopover, GlSprintf, GlLink } from '@gitlab/ui';
import FeatureListItem from 'ee/analytics/analytics_dashboards/components/list/feature_list_item.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';

describe('FeatureListItem', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgePopover = () => wrapper.findComponent(GlPopover);
  const findButton = () => wrapper.findComponent(GlButton);

  const defaultProps = {
    title: 'Hello world',
    description: 'Some description',
    to: 'some-path',
  };

  const createWrapper = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(FeatureListItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf: stubComponent(GlSprintf, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the feature title', () => {
      expect(wrapper.text()).toContain(defaultProps.title);
    });

    it('renders the dashboard description', () => {
      expect(wrapper.text()).toContain(defaultProps.description);
    });

    it('renders the setup icon', () => {
      expect(findIcon().props()).toMatchObject({
        name: 'cloud-gear',
        size: 16,
      });
    });

    it('renders the button with default text', () => {
      expect(findButton().text()).toBe('Set up');
    });
  });

  describe('button path', () => {
    beforeEach(() => {
      createWrapper({ to: 'foo-bar' }, mountExtended);
    });

    it('renders the button link', () => {
      expect(findButton().attributes('href')).toBe('foo-bar');
    });
  });

  describe('badge text', () => {
    beforeEach(() => {
      createWrapper({ badgeText: 'waiting' });
    });

    it('renders a badge with the badge text', () => {
      expect(findBadge().text()).toBe('waiting');
    });
  });

  describe('badge popover', () => {
    it('renders a popover with the expected text', () => {
      createWrapper({ badgeText: 'waiting', badgePopoverText: 'waiting for the foo to bar.' });
      const popover = findBadgePopover();

      expect(popover.text()).toBe('waiting for the foo to bar.');
      expect(popover.props('target')).toBe(findBadge().attributes('id'));
    });

    it('renders a popover with link when provided', () => {
      createWrapper({
        badgeText: 'waiting',
        badgePopoverText: 'waiting for the foo to bar %{linkStart}Learn more%{linkEnd}.',
        badgePopoverLink: '/foo',
      });

      expect(findBadgePopover().findComponent(GlLink).attributes('href')).toBe('/foo');
    });
  });

  describe('action text', () => {
    beforeEach(() => {
      createWrapper({ actionText: 'do something' });
    });

    it('renders button with the expected text', () => {
      expect(findButton().text()).toBe('do something');
    });
  });
});
