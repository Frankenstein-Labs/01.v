import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchPatternItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_item.vue';

describe('BranchPatternItem', () => {
  let wrapper;

  const defaultBranchPattern = {
    source: { pattern: 'feature/*' },
    target: { pattern: 'main' },
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(BranchPatternItem, {
      propsData: {
        branch: props.branch || {},
        ...props,
      },
    });
  };

  const findSourceInput = () => wrapper.findComponentByTestId('source-input');
  const findTargetInput = () => wrapper.findComponentByTestId('target-input');
  const findRemoveButton = () => wrapper.findComponent(GlButton);
  const findErrorMessage = () => wrapper.findByTestId('error-message');

  describe('rendering', () => {
    it('renders the component with empty inputs when no pattern is provided', () => {
      createComponent();

      expect(findSourceInput().exists()).toBe(true);
      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().exists()).toBe(true);
      expect(findTargetInput().props('value')).toBe('');
      expect(findRemoveButton().exists()).toBe(true);
      expect(findRemoveButton().props('icon')).toBe('remove');
    });

    it('renders the component with pattern values when provided', () => {
      createComponent({ props: { branch: defaultBranchPattern } });

      expect(findSourceInput().props('value')).toBe('feature/*');
      expect(findTargetInput().props('value')).toBe('main');
    });

    it('renders the component with correct placeholders', () => {
      createComponent();

      expect(findSourceInput().props('placeholder')).toBe('input source branch');
      expect(findTargetInput().props('placeholder')).toBe('input target branch');
    });
  });

  describe('behavior', () => {
    it('emits remove event when remove button is clicked', () => {
      createComponent();

      findRemoveButton().vm.$emit('click');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });

    it('handles branch pattern with missing source or target properties', () => {
      createComponent({
        props: {
          branch: {
            source: null,
            target: { pattern: 'main' },
          },
        },
      });

      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().props('value')).toBe('main');
    });

    it('handles branch with empty source pattern or target pattern', () => {
      createComponent({
        props: {
          branch: {
            source: { pattern: '' },
            target: { pattern: '' },
          },
        },
      });

      expect(findSourceInput().props('value')).toBe('');
      expect(findTargetInput().props('value')).toBe('');
    });

    it('handles backward compatibility with target.name', () => {
      createComponent({
        props: {
          branch: {
            source: { pattern: 'feature/*' },
            target: { name: 'main' },
          },
        },
      });

      expect(findSourceInput().props('value')).toBe('feature/*');
      expect(findTargetInput().props('value')).toBe('main');
    });

    it('emits branch patterns', async () => {
      createComponent();

      await findSourceInput().vm.$emit('input', 'source');

      expect(wrapper.emitted('set-branch')).toEqual([[{ source: { pattern: 'source' } }]]);

      await findTargetInput().vm.$emit('input', 'target');

      expect(wrapper.emitted('set-branch')[1]).toEqual([{ target: { pattern: 'target' } }]);
    });
  });

  describe('validation error handling', () => {
    it('shows error message when hasValidationError is true', () => {
      createComponent({
        props: {
          hasValidationError: true,
          errorMessage: 'Custom error message',
        },
      });

      const errorMessage = wrapper.findByTestId('error-message');
      expect(errorMessage.exists()).toBe(true);
      expect(errorMessage.text()).toBe('Custom error message');
      expect(errorMessage.classes()).toContain('gl-text-danger');
    });

    it('hides error message when hasValidationError is false', () => {
      createComponent({
        props: {
          hasValidationError: false,
          errorMessage: 'Some error message',
        },
      });

      expect(findErrorMessage().exists()).toBe(false);
    });

    it('uses default error message when none provided', () => {
      createComponent({
        props: {
          hasValidationError: true,
        },
      });

      const errorMessage = findErrorMessage();
      expect(errorMessage.exists()).toBe(true);
      expect(errorMessage.text()).toBe('Please remove duplicates.');
    });

    it('sets input state to invalid when hasValidationError is true', () => {
      createComponent({
        props: {
          hasValidationError: true,
        },
      });

      expect(findSourceInput().props('state')).toBe(false);
      expect(findTargetInput().props('state')).toBe(false);
    });

    it('sets input state to valid when hasValidationError is false', () => {
      createComponent({
        props: {
          hasValidationError: false,
        },
      });

      expect(findSourceInput().props('state')).toBe(true);
      expect(findTargetInput().props('state')).toBe(true);
    });
  });
});
