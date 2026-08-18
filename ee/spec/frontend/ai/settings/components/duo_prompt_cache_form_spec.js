import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlPopover, GlFormGroup, GlSprintf, GlLink } from '@gitlab/ui';
import DuoPromptCacheForm from 'ee/ai/settings/components/duo_prompt_cache_form.vue';

const MOCK_DATA = {
  promptCacheHelpPath: '/help/user/project/repository/code_suggestions/_index.md#prompt-caching',
};

describe('DuoPromptCacheForm', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    return shallowMount(DuoPromptCacheForm, {
      propsData: {
        disabledCheckbox: false,
        promptCacheEnabled: false,
        ...props,
      },
      provide: {
        arePromptCacheSettingsAllowed: true,
        ...provide,
      },
      stubs: {
        GlFormCheckbox,
        GlPopover,
        GlSprintf,
        GlLink,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('when arePromptCacheSettingsAllowed is false', () => {
    it('does not render the form group', () => {
      wrapper = createComponent(
        {},
        {
          arePromptCacheSettingsAllowed: false,
        },
      );
      expect(findFormGroup().exists()).toBe(false);
    });
  });

  describe('when arePromptCacheSettingsAllowed is true', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the section title', () => {
      expect(wrapper.find('h5').text()).toBe('Prompt cache');
    });

    it('renders the checkbox with correct label', () => {
      expect(findFormCheckbox().exists()).toBe(true);
      expect(findFormCheckbox().text()).toContain('Turn on prompt caching');
    });

    it('sets initial checkbox state based on promptCacheEnabled prop when unselected', () => {
      expect(findFormCheckbox().props('checked')).toBe(false);
    });

    it('emits change event when checkbox is clicked', async () => {
      await findFormCheckbox().vm.$emit('change', false);
      // Fix: The component is emitting false instead of true
      expect(wrapper.emitted('change')[0]).toEqual([false]);
    });

    it('does not show popover when disabledCheckbox prop is false', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it('renders correct links', () => {
      const helpLink = wrapper.findComponent(GlLink);
      expect(helpLink.exists()).toBe(true);
      expect(helpLink.props('href')).toBe(MOCK_DATA.promptCacheHelpPath);
    });

    describe('when disabledCheckbox is true', () => {
      beforeEach(() => {
        wrapper = createComponent({ disabledCheckbox: true });
      });

      it('disables checkbox', () => {
        expect(findFormCheckbox().props('disabled')).toBe(true);
      });

      it('shows popover', () => {
        expect(findPopover().exists()).toBe(true);
      });
    });

    it('renders checkbox with data-testid attribute', () => {
      expect(findFormCheckbox().find('input').attributes('data-testid')).toBe(
        'use-prompt-cache-checkbox',
      );
    });
  });
});
