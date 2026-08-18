import { GlLoadingIcon } from '@gitlab/ui';
import PolicyExceptionsLoader from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions_loader.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PolicyExceptionsLoader', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsLoader, {
      propsData,
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findLabel = () => wrapper.findByTestId('label');

  describe('default rendering', () => {
    it('renders only loading icon by default', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLabel().exists()).toBe(false);
    });

    it('renders icon with label', () => {
      createComponent({
        propsData: {
          label: 'label',
        },
      });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLabel().exists()).toBe(true);
      expect(findLabel().text()).toBe('label');
    });
  });
});
