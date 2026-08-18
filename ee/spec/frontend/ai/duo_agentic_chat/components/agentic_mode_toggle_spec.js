import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgenticModeToggle from 'ee/ai/duo_agentic_chat/components/agentic_mode_toggle.vue';

describe('AgenticModeToggle', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AgenticModeToggle, {
      propsData: { value: false, ...props },
    });
  };

  const findToggle = () => wrapper.findComponent(GlToggle);
  const findLabel = () => wrapper.find('span');

  describe('rendering', () => {
    it('passes value prop to GlToggle', () => {
      createComponent({ value: true });

      expect(findToggle().props('value')).toBe(true);
    });

    it('sets label-position to "left"', () => {
      createComponent();

      expect(findToggle().props('labelPosition')).toBe('left');
    });

    it('renders the "Agentic" label text', () => {
      createComponent();

      expect(findLabel().text()).toBe('Agentic');
    });

    it('is enabled by default', () => {
      createComponent();

      expect(findToggle().props('disabled')).toBe(false);
    });

    it('passes disabled prop through to GlToggle', () => {
      createComponent({ disabled: true });

      expect(findToggle().props('disabled')).toBe(true);
    });
  });

  describe('events', () => {
    it('emits change with the new value when the toggle changes', async () => {
      createComponent({ value: false });

      await findToggle().vm.$emit('change', true);

      expect(wrapper.emitted('change')).toEqual([[true]]);
    });

    it('emits change with false when toggled off', async () => {
      createComponent({ value: true });

      await findToggle().vm.$emit('change', false);

      expect(wrapper.emitted('change')).toEqual([[false]]);
    });
  });
});
