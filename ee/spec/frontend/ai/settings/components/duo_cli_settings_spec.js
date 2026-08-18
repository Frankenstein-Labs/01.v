import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import DuoCliSettings from 'ee/ai/settings/components/duo_cli_settings.vue';

describe('DuoCliSettings', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(DuoCliSettings, {
      propsData: {
        duoCliEnabled: true,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  beforeEach(() => {
    createComponent();
  });

  it('renders the form group with the correct label', () => {
    expect(findFormGroup().exists()).toBe(true);
    expect(findFormGroup().text()).toContain('GitLab Duo CLI access');
  });

  it('renders the checkbox with the correct label', () => {
    expect(findCheckbox().exists()).toBe(true);
    expect(findCheckbox().text()).toContain('Turn on GitLab Duo CLI access');
  });

  describe('checkbox state', () => {
    it('is checked when duoCliEnabled is true', () => {
      createComponent({ props: { duoCliEnabled: true } });

      expect(findCheckbox().props('checked')).toBe(true);
    });

    it('is unchecked when duoCliEnabled is false', () => {
      createComponent({ props: { duoCliEnabled: false } });

      expect(findCheckbox().props('checked')).toBe(false);
    });
  });

  describe('disabled state', () => {
    it('disables the checkbox when disabled prop is true', () => {
      createComponent({ props: { disabled: true } });

      expect(findCheckbox().props('disabled')).toBe(true);
    });

    it('does not disable the checkbox when disabled prop is false', () => {
      createComponent({ props: { disabled: false } });

      expect(findCheckbox().props('disabled')).toBe(false);
    });
  });

  describe('change event', () => {
    it('emits change with true when checkbox is checked', async () => {
      createComponent({ props: { duoCliEnabled: false } });

      await findCheckbox().vm.$emit('change', true);

      expect(wrapper.emitted('change')).toHaveLength(1);
      expect(wrapper.emitted('change')[0]).toEqual([true]);
    });

    it('emits change with false when checkbox is unchecked', async () => {
      createComponent({ props: { duoCliEnabled: true } });

      await findCheckbox().vm.$emit('change', false);

      expect(wrapper.emitted('change')).toHaveLength(1);
      expect(wrapper.emitted('change')[0]).toEqual([false]);
    });
  });
});
