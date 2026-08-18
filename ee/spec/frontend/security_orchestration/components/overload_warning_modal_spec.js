import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';

describe('OverloadWarningModal', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMount(OverloadWarningModal, {
      propsData,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('hides modal by default', () => {
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('visible modal', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          visible: true,
        },
      });
    });

    it('shows modal when visible property is true', () => {
      expect(findModal().props('visible')).toBe(true);
    });

    it('emits confirm event', () => {
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('confirm-submit')).toHaveLength(1);
    });

    it('emits cancel event', () => {
      findModal().vm.$emit('secondary');
      findModal().vm.$emit('canceled');
      findModal().vm.$emit('change');

      expect(wrapper.emitted('cancel-submit')).toHaveLength(3);
    });
  });
});
