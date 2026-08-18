import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformSecurityForm from 'ee/ai/settings/components/duo_agent_platform_security_form.vue';

let wrapper;

const selfHostedDuoAgentPlatformServiceSecure = false;
const createComponent = ({ props = {} } = {}) => {
  wrapper = extendedWrapper(
    shallowMount(DuoAgentPlatformSecurityForm, {
      propsData: {
        value: selfHostedDuoAgentPlatformServiceSecure,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
      },
    }),
  );
};

const findDuoAgentPlatformSecurityForm = () => wrapper.findComponent(DuoAgentPlatformSecurityForm);
const findSecurityForm = () => wrapper.findComponent(GlFormGroup);
const findSecureCheckbox = () => wrapper.findComponent(GlFormCheckbox);
const findSecureCheckboxLabel = () => wrapper.findByTestId('secure-checkbox-label');
const findSecureCheckboxHelpText = () => wrapper.findByTestId('secure-checkbox-help-text');

describe('DuoAgentPlatformSecurityForm', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findDuoAgentPlatformSecurityForm().exists()).toBe(true);
  });

  describe('secure checkbox', () => {
    it('renders the checkbox and security heading', () => {
      expect(findSecureCheckbox().exists()).toBe(true);
      expect(findSecurityForm().attributes('label')).toBe('Security');
    });

    it('has the correct label and help text', () => {
      expect(findSecureCheckboxLabel().text()).toBe(
        'Use TLS for the GitLab Duo Agent Platform service',
      );
      expect(findSecureCheckboxHelpText().text()).toBe(
        'Turn off only if your local service endpoint does not support TLS.',
      );
    });

    it('renders the checkbox with initial value', () => {
      expect(findSecureCheckbox().props('checked')).toBe(selfHostedDuoAgentPlatformServiceSecure);
    });

    it('emits secure-change event when toggled', async () => {
      findSecureCheckbox().vm.$emit('input', true);
      await nextTick();

      expect(wrapper.emitted('secure-change')).toEqual([[true]]);
    });
  });
});
