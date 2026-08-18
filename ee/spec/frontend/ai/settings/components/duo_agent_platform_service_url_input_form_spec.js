import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformServiceUrlInputForm from 'ee/ai/settings/components/duo_agent_platform_service_url_input_form.vue';

let wrapper;

const duoAgentPlatformServiceUrl = 'localhost:50052';
const createComponent = ({ props = {} } = {}) => {
  wrapper = extendedWrapper(
    shallowMount(DuoAgentPlatformServiceUrlInputForm, {
      propsData: {
        value: duoAgentPlatformServiceUrl,
        ...props,
      },
      stubs: {
        GlFormGroup,
      },
    }),
  );
};

const findDuoAgentPlatformServiceUrlInputForm = () =>
  wrapper.findComponent(DuoAgentPlatformServiceUrlInputForm);
const findFormInput = () => wrapper.findComponent(GlFormInput);

describe('DuoAgentPlatformServiceUrlInputForm', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findDuoAgentPlatformServiceUrlInputForm().exists()).toBe(true);
  });

  describe('form input', () => {
    it('renders the form group with correct label', () => {
      const formGroup = wrapper.findComponent(GlFormGroup);
      expect(formGroup.attributes('label')).toEqual(
        'Local URL for the GitLab Duo Agent Platform service',
      );
    });

    it('renders the correct value', () => {
      expect(findFormInput().attributes('value')).toEqual(duoAgentPlatformServiceUrl);
    });

    it('emits a change event when updated', async () => {
      const newDuoAgentPlatformServiceUrl = 'new-duo-agent-platform-url:50052';
      findFormInput().vm.$emit('update', newDuoAgentPlatformServiceUrl);

      await nextTick();

      expect(wrapper.emitted('change')).toEqual([[newDuoAgentPlatformServiceUrl]]);
    });
  });
});
