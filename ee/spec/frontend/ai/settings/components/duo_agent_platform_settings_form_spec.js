import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import DuoAgentPlatformSettingsForm from 'ee/ai/settings/components/duo_agent_platform_settings_form.vue';

describe('DuoAgentPlatformSettingsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, slots = {}, provide = {} } = {}) => {
    wrapper = shallowMount(DuoAgentPlatformSettingsForm, {
      propsData: {
        enabled: true,
        ...props,
      },
      provide: {
        showDuoAgentPlatformEnablementSetting: true,
        ...provide,
      },
      slots,
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findChildSettingsContainer = () =>
    wrapper.find('[data-testid="dap-child-settings-disabled-message"]');

  beforeEach(() => {
    createComponent();
  });

  describe('form group visibility', () => {
    it('renders the form group when showDuoAgentPlatformEnablementSetting is true', () => {
      createComponent({
        provide: {
          showDuoAgentPlatformEnablementSetting: true,
        },
      });

      expect(findFormGroup().exists()).toBe(true);
    });

    it('does not render the form group when showDuoAgentPlatformEnablementSetting is false', () => {
      createComponent({
        provide: {
          showDuoAgentPlatformEnablementSetting: false,
        },
      });

      expect(findFormGroup().exists()).toBe(false);
    });
  });

  it('renders the form group with label', () => {
    expect(findFormGroup().text()).toContain('GitLab Duo Agent Platform');
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().exists()).toBe(true);
    expect(findFormCheckbox().text()).toContain(
      'Turn on GitLab Duo Agentic Chat, agents, and flows',
    );
  });

  describe('checkbox behavior', () => {
    it('is checked when enabled prop is true', () => {
      createComponent({
        props: {
          enabled: true,
        },
      });

      expect(findFormCheckbox().props('checked')).toBe(true);
    });

    it('is unchecked when enabled prop is false', () => {
      createComponent({
        props: {
          enabled: false,
        },
      });

      expect(findFormCheckbox().props('checked')).toBe(false);
    });

    it('emits selected event with true when checkbox is checked', async () => {
      createComponent({
        props: {
          enabled: false,
        },
      });

      await findFormCheckbox().vm.$emit('input', true);

      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([true]);
    });

    it('emits selected event with false when checkbox is unchecked', async () => {
      createComponent({
        props: {
          enabled: true,
        },
      });

      await findFormCheckbox().vm.$emit('input', false);

      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([false]);
    });
  });

  describe('child settings disabled banner', () => {
    describe('when showDuoAgentPlatformEnablementSetting is true', () => {
      it('does not show banner when enabled and not disabledCheckbox', () => {
        createComponent({ props: { enabled: true, disabledCheckbox: false } });

        expect(findChildSettingsContainer().exists()).toBe(false);
      });

      it('shows banner when DAP is turned off', () => {
        createComponent({ props: { enabled: false, disabledCheckbox: false } });

        expect(findChildSettingsContainer().exists()).toBe(true);
        expect(findChildSettingsContainer().text()).toContain(
          'These settings are disabled because GitLab Duo Agent Platform is turned off.',
        );
      });

      it('does not show banner when disabledCheckbox is true (outer form already shows it)', () => {
        createComponent({ props: { enabled: false, disabledCheckbox: true } });

        expect(findChildSettingsContainer().exists()).toBe(false);
      });
    });

    describe('when showDuoAgentPlatformEnablementSetting is false', () => {
      it('never shows banner even when DAP is disabled', () => {
        createComponent({
          props: { enabled: false, disabledCheckbox: false },
          provide: { showDuoAgentPlatformEnablementSetting: false },
        });

        expect(findChildSettingsContainer().exists()).toBe(false);
      });
    });
  });

  describe('disabled state', () => {
    it('disables the checkbox when disabledCheckbox prop is true', () => {
      createComponent({ props: { disabledCheckbox: true } });

      expect(findFormCheckbox().props('disabled')).toBe(true);
    });

    it('does not disable the checkbox when disabledCheckbox prop is false', () => {
      createComponent({ props: { disabledCheckbox: false } });

      expect(findFormCheckbox().props('disabled')).toBe(false);
    });

    it('does not show lock icon button when disabled', () => {
      createComponent({ props: { disabledCheckbox: true } });

      expect(wrapper.find('button[type="button"]').exists()).toBe(false);
    });
  });
});
