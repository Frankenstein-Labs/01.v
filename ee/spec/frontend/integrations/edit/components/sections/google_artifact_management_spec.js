import Vue, { nextTick } from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import IntegrationSectionGoogleArtifactManagement from 'ee/integrations/edit/components/sections/google_artifact_management.vue';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import Connection from '~/integrations/edit/components/sections/connection.vue';
import ConfigurationInstructions from 'ee/integrations/edit/components/google_artifact_management/configuration_instructions.vue';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import EmptyState from 'ee/integrations/edit/components/google_artifact_management/empty_state.vue';
import { useIntegrationForm } from '~/integrations/edit/store';
import { mockIntegrationProps } from '../../mock_data';

Vue.use(PiniaVuePlugin);

describe('IntegrationSectionGoogleArtifactManagement', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(EmptyState);
  const findViewArtifactsButton = () => wrapper.findComponent(GlButton);
  const findConfigurationInstructions = () => wrapper.findComponent(ConfigurationInstructions);
  const findConfiguration = () => wrapper.findComponent(Configuration);
  const findConnection = () => wrapper.findComponent(Connection);
  const findTitle = () => wrapper.find('h2');

  const createComponent = (customState = {}) => {
    const pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      customState: {
        ...mockIntegrationProps,
        ...customState,
      },
    });

    wrapper = shallowMount(IntegrationSectionGoogleArtifactManagement, {
      propsData: {
        isValidated: false,
      },
      pinia,
      stubs: { SettingsSection },
    });
  };

  it('renders EmptyState when editable is false & workloadIdentityFederationPath is defined', () => {
    createComponent({
      editable: false,
      googleArtifactManagementProps: {
        ...mockIntegrationProps.googleArtifactManagementProps,
        workloadIdentityFederationPath: '/path/to/wlif',
      },
    });

    expect(findEmptyState().props()).toMatchObject({
      path: '/path/to/wlif',
    });
  });

  it('does not render EmptyState when editable is true', () => {
    createComponent();

    expect(findEmptyState().exists()).toBe(false);
  });

  it('renders a button to view artifacts', () => {
    createComponent();

    expect(findViewArtifactsButton().text()).toBe('View artifacts');
    expect(findViewArtifactsButton().props('icon')).toBe('deployments');
    expect(findViewArtifactsButton().attributes('href')).toBe('/path/to/artifact/registry');
  });

  it('hides button to view artifacts when `operating=false`', () => {
    createComponent({ operating: false });

    expect(findViewArtifactsButton().exists()).toBe(false);
  });

  it('renders connection component', () => {
    createComponent();

    expect(findConnection().exists()).toBe(true);
  });

  it('emits toggle-integration-active event when connection component emits event', () => {
    createComponent();

    findConnection().vm.$emit('toggle-integration-active', true);

    expect(wrapper.emitted('toggle-integration-active')).toEqual([[true]]);
  });

  it('renders form title', () => {
    createComponent();

    expect(findTitle().text()).toBe('1. Repository');
  });

  it('renders configuration component', () => {
    createComponent();

    expect(findConfiguration().props()).toMatchObject({
      fields: mockIntegrationProps.fields,
      isValidated: false,
    });
  });

  it('renders configuration instructions', () => {
    createComponent();

    expect(findConfigurationInstructions().props('id')).toBe('');
  });

  it('renders configuration instructions with id prop filled', () => {
    createComponent({ fields: [{ name: 'artifact_registry_project_id', value: 'project-id' }] });

    expect(findConfigurationInstructions().props('id')).toBe('project-id');
  });

  it('updates configuration instructions id prop when configuration component emits update event', async () => {
    createComponent();

    findConfiguration().vm.$emit('update', {
      value: 'project-id',
      field: mockIntegrationProps.fields[0],
    });

    await nextTick();

    expect(findConfigurationInstructions().props('id')).toBe('project-id');
  });
});
