import { GlBadge, GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ImmutableBadge from 'ee/packages_and_registries/container_registry/explorer/components/details_page/immutable_badge.vue';

describe('Immutable Badge', () => {
  let wrapper;

  const defaultProps = {
    tag: {
      name: 'test',
      protection: {
        immutable: true,
      },
    },
    tagRowId: 'test_badge',
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ImmutableBadge, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('when tag is immutable', () => {
    it('displays badge and popover', () => {
      createComponent();

      expect(findBadge().text()).toBe('immutable');
      expect(findBadge().attributes('id')).toBe('test_badge');
      expect(findPopover().props('target')).toBe('test_badge');
    });
  });

  describe('when tag is not immutable', () => {
    it('does not display badge or popover', () => {
      createComponent({
        tag: {
          name: 'test2',
          protection: {
            immutable: false,
          },
        },
      });

      expect(findBadge().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });
  });
});
