import { GlButton, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyExceptionsSelectedItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selected_item.vue';

describe('PolicyExceptionsSelectedItem', () => {
  let wrapper;

  const defaultProps = {
    count: 2,
    title: 'Roles',
    exceptionKey: 'roles',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsSelectedItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findSelectButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findRemoveButton = () => wrapper.findAllComponents(GlButton).at(1);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('displays correct button text for single exception', () => {
      createComponent({ count: 1 });
      expect(findSelectButton().text()).toBe('(1) Exception');
    });

    it('displays correct button text for multiple exceptions', () => {
      createComponent({ count: 3 });
      expect(findSelectButton().text()).toBe('(3) Exceptions');
    });

    it('displays the title correctly', () => {
      expect(wrapper.text()).toContain('Roles');
    });

    it('renders remove button with correct aria-label', () => {
      expect(findRemoveButton().attributes('aria-label')).toBe('Remove');
      expect(findRemoveButton().props('icon')).toBe('remove');
    });
  });

  describe('interactions', () => {
    it('emits select-item event when select button is clicked', async () => {
      await findSelectButton().vm.$emit('click');

      expect(wrapper.emitted('select-item')).toEqual([['roles']]);
    });

    it('emits remove event when remove button is clicked', async () => {
      await findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove')).toEqual([['roles']]);
    });

    it('emits correct exception key', async () => {
      createComponent({ exceptionKey: 'branches' });

      await findSelectButton().vm.$emit('click');
      await findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('select-item')).toEqual([['branches']]);
      expect(wrapper.emitted('remove')).toEqual([['branches']]);
    });
  });

  describe('edge cases', () => {
    it('handles zero count', () => {
      createComponent({ count: 0 });
      expect(findSelectButton().text()).toBe('(0) Exceptions');
    });

    it('handles empty title', () => {
      createComponent({ title: '' });
      expect(wrapper.exists()).toBe(true);
    });
  });
});
