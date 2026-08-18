import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { GlSprintf } from '@gitlab/ui';
import GcIamForm from 'ee/integrations/edit/components/google_cloud_iam/form.vue';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

Vue.use(PiniaVuePlugin);

describe('IntegrationSectionGoogleCloudIAM', () => {
  let wrapper;

  const createComponent = ({ fields = [], suggestedPoolId = null } = {}) => {
    const pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      defaultState: {},
    });

    wrapper = shallowMount(GcIamForm, {
      pinia,
      propsData: { fields, suggestedPoolId },
      stubs: { GlSprintf },
    });
  };

  const findConfigurations = () => wrapper.findAllComponents(Configuration);
  const findHeaders = () => wrapper.findAll('h3');

  it('shows two headers', () => {
    createComponent();
    const headers = findHeaders();

    expect(headers.at(0).text()).toBe('Google Cloud project');
    expect(headers.at(1).text()).toBe('Workload identity federation');
  });

  it('renders suggestedPoolId prop', () => {
    createComponent({ suggestedPoolId: 'capybara-pool' });

    expect(wrapper.findAll('p').at(1).text()).toMatch(/capybara-pool/);
  });

  describe('Configuration components', () => {
    it('renders Google Cloud project fields', () => {
      createComponent({
        fields: [
          { name: 'workload_identity_federation_project_id', type: 'input' },
          { name: 'dummy', type: 'input' }, // Ignored,
        ],
      });

      const configurations = findConfigurations();
      expect(configurations.at(0).props('fields')).toHaveLength(1);
      expect(configurations.at(1).props('fields')).toHaveLength(0);
    });

    it('renders Workload identity federation fields', () => {
      createComponent({
        fields: [
          { name: 'workload_identity_pool_id', type: 'input' },
          { name: 'dummy', type: 'input' }, // Ignored,
        ],
      });

      const configurations = findConfigurations();
      expect(configurations.at(0).props('fields')).toHaveLength(0);
      expect(configurations.at(1).props('fields')).toHaveLength(1);
    });
  });
});
