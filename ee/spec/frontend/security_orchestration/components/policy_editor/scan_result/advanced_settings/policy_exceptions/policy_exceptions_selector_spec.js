import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';

describe('PolicyExceptionsSelector', () => {
  let wrapper;

  const createComponent = ({ glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsSelector, {
      provide: {
        glFeatures: {
          ...glFeatures,
        },
      },
    });
  };

  const findPolicyExceptionSelectors = () => wrapper.findAllByTestId('exception-type');

  describe('all features', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders policy exceptions options', () => {
      expect(findPolicyExceptionSelectors()).toHaveLength(6);
    });

    it('selects policy exceptions option', () => {
      findPolicyExceptionSelectors().at(1).findComponent(GlButton).vm.$emit('click');

      expect(wrapper.emitted('select')).toEqual([['groups']]);
    });
  });
});
