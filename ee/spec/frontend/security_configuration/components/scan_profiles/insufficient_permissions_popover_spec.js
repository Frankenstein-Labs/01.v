import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InsufficientPermissionsPopover from 'ee/security_configuration/components/scan_profiles/insufficient_permissions_popover.vue';

describe('InsufficientPermissionsPopover', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(InsufficientPermissionsPopover, {
      propsData: {
        target: 'test-button',
        ...props,
      },
      stubs: {
        GlPopover,
      },
    });
  };

  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('rendering', () => {
    it('renders popover with correct target', () => {
      createComponent({ target: 'apply-button' });

      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('target')).toBe('apply-button');
    });

    it('renders popover with default placement', () => {
      createComponent();

      expect(findPopover().props('placement')).toBe('top');
    });

    it('renders popover with custom placement', () => {
      createComponent({ placement: 'bottom' });

      expect(findPopover().props('placement')).toBe('bottom');
    });

    it('renders title slot content', () => {
      createComponent();

      expect(wrapper.text()).toContain('Action unavailable');
    });

    it('renders description content', () => {
      createComponent();

      expect(wrapper.text()).toContain(
        'Only a project maintainer or owner can apply or disable profiles.',
      );
    });
  });
});
