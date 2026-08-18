import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import DuoWorkflowPromptInjectionForm from 'ee/ai/settings/components/duo_workflow_prompt_injection_form.vue';
import { PROTECTION_LEVEL_OPTIONS } from 'ee/ai/settings/constants';

describe('DuoWorkflowSettingsForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(DuoWorkflowPromptInjectionForm, {
      propsData: {
        promptInjectionProtectionLevel: 'interrupt',
        showProtection: true,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlFormRadioGroup,
        GlFormCheckbox: stubComponent(GlFormCheckbox, {
          template: `<div>
                      <slot></slot>
                      <slot name="help"></slot>
                    </div>`,
        }),
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  const findGlFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findRadios = () => wrapper.findAllComponents(GlFormRadio);

  describe('Prompt Injection Protection Section', () => {
    it('renders the protection section with correct label', () => {
      expect(findGlFormGroup().exists()).toBe(true);
      expect(wrapper.text()).toContain('Prompt injection protection');
    });

    it('renders the protection description as label-description', () => {
      expect(wrapper.text()).toContain(
        'Control how GitLab Duo handles potential prompt injection attempts',
      );
    });

    it('renders radio group with correct attributes', () => {
      expect(findRadioGroup().attributes('data-testid')).toBe(
        'prompt-injection-protection-level-radio-group',
      );
      expect(findRadioGroup().props('name')).toBe(
        'namespace[ai_settings_attributes][prompt_injection_protection_level]',
      );
    });

    it('renders all three protection level options', () => {
      expect(findRadios()).toHaveLength(3);
    });

    it.each(PROTECTION_LEVEL_OPTIONS)(
      'renders $value option with correct text and description',
      (option) => {
        const radioIndex = PROTECTION_LEVEL_OPTIONS.findIndex((opt) => opt.value === option.value);
        const radio = findRadios().at(radioIndex);

        expect(radio.text()).toContain(option.text);
        expect(radio.text()).toContain(option.description);
        expect(radio.attributes('data-testid')).toBe(
          `prompt-injection-protection-${option.value}-radio`,
        );
      },
    );

    describe('when radio selection changes', () => {
      beforeEach(async () => {
        findRadioGroup().vm.$emit('change', 'log_only');
        await nextTick();
      });

      it('emits protection-level-change event with correct value', () => {
        expect(wrapper.emitted('protection-level-change')[0]).toEqual(['log_only']);
      });
    });

    it('hides protection section when showProtection is false', () => {
      wrapper = createComponent({ showProtection: false });
      expect(wrapper.findComponent(GlFormGroup).exists()).toBe(false);
    });
  });

  describe('Form Attributes', () => {
    it('renders radio options with proper styling', () => {
      const radios = findRadios();
      radios.wrappers.forEach((radio) => {
        const div = radio.find('div');
        expect(div.exists()).toBe(true);
        const description = div.find('.gl-text-subtle');
        expect(description.exists()).toBe(true);
      });
    });
  });
});
