import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import IntegrationSectionGoogleCloudIAM from 'ee_component/integrations/edit/components/sections/google_cloud_iam.vue';
import GcIamForm from 'ee/integrations/edit/components/google_cloud_iam/form.vue';
import ManualSetup from 'ee/integrations/edit/components/google_cloud_iam/manual_setup.vue';
import SetupScript from 'ee/integrations/edit/components/google_cloud_iam/setup_script.vue';
import Connection from '~/integrations/edit/components/sections/connection.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

Vue.use(PiniaVuePlugin);

describe('IntegrationSectionGoogleCloudIAM', () => {
  const wlifIssuer = 'https://test.com';
  const jwtClaims = 'examplegcpattr=exampleglattr';
  let wrapper;

  const createComponent = ({
    fields = [],
    integrationLevel = 'project',
    projectId = 303,
    groupId = 808,
  } = {}) => {
    const pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      customState: {
        fields,
        wlifIssuer,
        jwtClaims,
        integrationLevel,
        projectId,
        groupId,
      },
    });

    wrapper = shallowMount(IntegrationSectionGoogleCloudIAM, {
      pinia,
    });
  };

  const findConnection = () => wrapper.findComponent(Connection);
  const findGcIamForm = () => wrapper.findComponent(GcIamForm);
  const findManualSetup = () => wrapper.findComponent(ManualSetup);
  const findSetupScript = () => wrapper.findComponent(SetupScript);

  describe('when Google Cloud IAM form is empty', () => {
    it('renders the manual setup state', () => {
      createComponent();

      expect(findManualSetup().exists()).toBe(true);
      expect(findSetupScript().props()).toMatchObject({
        googleProjectId: '<your_google_cloud_project_id>',
        identityPoolId: '<your_identity_pool_id>',
        identityProviderId: '<your_identity_provider_id>',
      });
    });
  });

  describe('when Google Cloud IAM form is not empty', () => {
    it('renders the Google Cloud IAM form', () => {
      createComponent({ fields: [{ value: '' }, { value: '1' }] });

      expect(findGcIamForm().exists()).toBe(true);
    });

    it('passes initial fields values to SetupScript', () => {
      createComponent({
        fields: [
          { name: 'workload_identity_federation_project_id', value: 'capybara' },
          { name: 'workload_identity_pool_id', value: 'redpanda' },
          { name: 'workload_identity_pool_provider_id', value: 'weasel' },
        ],
      });

      const setupScript = findSetupScript();
      expect(setupScript.props('googleProjectId')).toBe('capybara');
      expect(setupScript.props('identityPoolId')).toBe('redpanda');
      expect(setupScript.props('identityProviderId')).toBe('weasel');
    });

    it('passes existing identityPoolId as helpTextPoolId to ManualSetup', () => {
      createComponent({
        fields: [{ name: 'workload_identity_pool_id', value: 'redpanda' }],
      });

      const manualSetup = findManualSetup();
      expect(manualSetup.props('helpTextPoolId')).toBe('redpanda');
    });
  });

  it('renders Connection component', () => {
    createComponent();

    expect(findConnection().exists()).toBe(true);
  });

  it('pass `wlifIssuer` and `helpTextPoolId` prop to ManualSetup component', () => {
    createComponent();

    expect(findManualSetup().props('wlifIssuer')).toBe(wlifIssuer);
    expect(findManualSetup().props('helpTextPoolId')).toBe('gitlab-project-303');
  });

  it('pass `helpTextPoolId` prop to ManualSetup component when group integration', () => {
    createComponent({ integrationLevel: 'group', groupId: 111 });

    expect(findManualSetup().props('helpTextPoolId')).toBe('gitlab-group-111');
  });

  it('pass relevant props to SetupScript component', () => {
    createComponent();

    const setupScript = findSetupScript();
    expect(setupScript.exists()).toBe(true);
    expect(setupScript.props('wlifIssuer')).toBe(wlifIssuer);
    expect(setupScript.props('jwtClaims')).toBe(jwtClaims);
  });

  it('pass `suggestedDisplayName` to SetupScript when project integration', () => {
    createComponent();

    expect(findSetupScript().props('suggestedDisplayName')).toBe('GitLab project ID 303');
  });

  it('pass `suggestedDisplayName` to SetupScript when group integration', () => {
    createComponent({ integrationLevel: 'group', groupId: 111 });

    expect(findSetupScript().props('suggestedDisplayName')).toBe('GitLab group ID 111');
  });

  it.each`
    field                                        | value                         | prop
    ${'workload_identity_federation_project_id'} | ${'updated-project-id'}       | ${'googleProjectId'}
    ${'workload_identity_pool_id'}               | ${'updated-pool-id'}          | ${'identityPoolId'}
    ${'workload_identity_pool_provider_id'}      | ${'updated-pool-provider-id'} | ${'identityProviderId'}
  `(
    'updates $prop prop in SetupScript component when form field $field is updated',
    async ({ field, value, prop }) => {
      createComponent({
        fields: [
          { name: 'workload_identity_federation_project_id', value: 'my-sample-project' },
          { name: 'workload_identity_pool_id', value: 'my-pool-id' },
          { name: 'workload_identity_pool_provider_id', value: 'my-pool-provider-id' },
        ],
      });

      expect(findSetupScript().props()).toMatchObject({
        googleProjectId: 'my-sample-project',
        identityPoolId: 'my-pool-id',
        identityProviderId: 'my-pool-provider-id',
      });

      await findGcIamForm().vm.$emit('update', {
        field: { name: field },
        value,
      });

      expect(findSetupScript().props(prop)).toBe(value);
    },
  );
});
