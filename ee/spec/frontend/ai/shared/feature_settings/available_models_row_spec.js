import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import AvailableModelsRow from 'ee/ai/shared/feature_settings/available_models_row.vue';

describe('AvailableModelsRow', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AvailableModelsRow, {
      propsData: {
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findTooltipWrapper = () => wrapper.findByTestId('disabled-tooltip');
  const findTooltip = () => getBinding(findTooltipWrapper().element, 'gl-tooltip');
  const findIndicator = () => wrapper.findByTestId('allow-list-indicator');

  it('renders the Configure button', () => {
    createComponent();

    expect(findButton().text()).toBe('Configure');
  });

  describe('when `disabled` is false', () => {
    beforeEach(() => {
      createComponent({ disabled: false });
    });

    it('does not disable the button', () => {
      expect(findButton().attributes('disabled')).toBeUndefined();
    });

    it('disables the tooltip', () => {
      expect(findTooltip().value.disabled).toBe(true);
    });

    it('emits a `click` event when clicked', () => {
      findButton().vm.$emit('click');

      expect(wrapper.emitted('click')).toHaveLength(1);
    });
  });

  describe('when `disabled` is true', () => {
    beforeEach(() => {
      createComponent({ disabled: true });
    });

    it('disables the button', () => {
      expect(findButton().attributes('disabled')).toBeDefined();
    });

    it('enables the tooltip with the explanatory title', () => {
      expect(findTooltip().value.disabled).toBe(false);
      expect(findTooltip().value.title).toBe(
        'Available models can only be configured when using a GitLab managed model.',
      );
    });
  });

  describe('loading state', () => {
    it.each([true, false])('passes loading=%s to the button', (isLoading) => {
      createComponent({ isLoading });

      expect(findButton().props('loading')).toBe(isLoading);
    });
  });

  describe('allow-list indicator', () => {
    it('does not render the indicator when `allowList` is null', () => {
      createComponent({ allowList: null });

      expect(findIndicator().exists()).toBe(false);
      expect(findButton().exists()).toBe(true);
    });

    it('renders the allowed/total count when some models are allowed', () => {
      createComponent({
        allowList: {
          enabled: true,
          models: {
            nodes: [{ allowed: true }, { allowed: false }, { allowed: true }],
          },
        },
      });

      expect(findIndicator().text()).toBe('2 of 3 models allowed');
    });

    it('renders "All models allowed" when the allowlist is enabled and all models are allowed', () => {
      createComponent({
        allowList: {
          enabled: true,
          models: { nodes: [{ allowed: true }, { allowed: true }] },
        },
      });

      expect(findIndicator().text()).toBe('All models allowed');
    });

    it('renders "All models allowed" when the allowlist is disabled', () => {
      createComponent({
        allowList: {
          enabled: false,
          models: { nodes: [{ allowed: true }, { allowed: true }] },
        },
      });

      expect(findIndicator().text()).toBe('All models allowed');
    });
  });
});
