import { shallowMount } from '@vue/test-utils';
import { GlModal, GlButton } from '@gitlab/ui';
import RemoveLifecycleConfirmationModal from 'ee/groups/settings/work_items/custom_status/remove_lifecycle_confirmation_modal.vue';

describe('RemoveLifecycleConfirmationModal', () => {
  const defaultProps = {
    isVisible: true,
    lifecycleName: 'Test Lifecycle',
  };

  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(RemoveLifecycleConfirmationModal, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlModal, GlButton },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findCancelButton = () => wrapper.findComponent('[data-testid="remove-lifecycle-cancel"]');
  const findRemoveButton = () => wrapper.findComponent('[data-testid="remove-lifecycle-continue"]');

  describe('Component Rendering', () => {
    it('renders GlModal component with correct props', () => {
      createComponent();

      expect(findModal().exists()).toBe(true);
      expect(findModal().props()).toMatchObject({
        visible: true,
        title: 'Remove lifecycle: "Test Lifecycle"',
      });
    });

    it('renders modal with correct visibility when isVisible is false', () => {
      createComponent({ isVisible: false });

      expect(findModal().props()).toMatchObject({
        visible: false,
      });
    });

    it('renders cancel button with correct properties', () => {
      createComponent();

      expect(findCancelButton().exists()).toBe(true);
      expect(findCancelButton().text()).toBe('Cancel');
    });

    it('renders remove button with correct properties', () => {
      createComponent();

      expect(findRemoveButton().exists()).toBe(true);
      expect(findRemoveButton().props()).toMatchObject({
        variant: 'danger',
      });
      expect(findRemoveButton().text()).toBe('Remove');
    });
  });

  it('generates correct title with lifecycle name', () => {
    createComponent({ lifecycleName: 'My Custom Lifecycle' });

    expect(findModal().props('title')).toBe('Remove lifecycle: "My Custom Lifecycle"');
  });

  describe('Event Handling', () => {
    it('emits cancel event when modal is hidden', () => {
      createComponent();

      findModal().vm.$emit('hide');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });

    it('emits cancel event when cancel button is clicked', () => {
      createComponent();

      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });

    it('emits continue event when remove button is clicked', () => {
      createComponent();

      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('continue')).toHaveLength(1);
    });

    it('does not emit any events initially', () => {
      createComponent();

      expect(wrapper.emitted()).toEqual({});
    });
  });

  describe('Props Validation', () => {
    it('accepts valid props', () => {
      expect(() => {
        createComponent({
          isVisible: false,
          lifecycleName: 'Valid Lifecycle Name',
        });
      }).not.toThrow();
    });

    it('works with different lifecycle names', () => {
      const lifecycleNames = [
        'Short',
        'Very Long Lifecycle Name With Many Words',
        'Lifecycle123',
        'lifecycle-with-dashes',
        'lifecycle_with_underscores',
      ];

      lifecycleNames.forEach((name) => {
        createComponent({ lifecycleName: name });

        expect(findModal().props('title')).toBe(`Remove lifecycle: "${name}"`);
      });
    });
  });
});
