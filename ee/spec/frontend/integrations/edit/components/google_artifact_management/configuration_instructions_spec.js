import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { GlLink, GlSprintf } from '@gitlab/ui';
import ConfigurationInstructions from 'ee/integrations/edit/components/google_artifact_management/configuration_instructions.vue';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { useIntegrationForm } from '~/integrations/edit/store';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import { mockIntegrationProps } from '../../mock_data';

Vue.use(PiniaVuePlugin);

describe('ConfigurationInstructions', () => {
  let wrapper;

  const findHeader = () => wrapper.find('h2');
  const findCodeBlockHighlighted = () => wrapper.findComponent(CodeBlockHighlighted);
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findLinks = () => wrapper.findAllComponents(GlLink);

  const createComponent = ({ id = '', customState = {} } = {}) => {
    const pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      customState: { ...mockIntegrationProps, ...customState },
    });

    wrapper = shallowMount(ConfigurationInstructions, {
      propsData: {
        id,
      },
      pinia,
      stubs: {
        GlSprintf,
        SettingsSection,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders header', () => {
    expect(findHeader().text()).toBe('2. Set up permissions');
  });

  it('renders link to OIDC custom claims', () => {
    expect(findLinks().at(0).attributes()).toMatchObject({
      href: '/help/integration/google_cloud_iam#oidc-custom-claims',
      target: '_blank',
    });
  });

  it('renders link to Google Artifact Registry roles', () => {
    expect(findLinks().at(1).attributes()).toMatchObject({
      href: 'https://cloud.google.com/artifact-registry/docs/access-control#roles',
      target: '_blank',
    });
  });

  it('renders link to Google Cloud CLI installation', () => {
    expect(findLinks().at(2).attributes()).toMatchObject({
      href: 'https://cloud.google.com/sdk/docs/install',
      target: '_blank',
    });
  });

  it('renders link to Google Cloud IAM permissions', () => {
    expect(findLinks().at(3).attributes()).toMatchObject({
      href: 'https://cloud.google.com/iam/docs/granting-changing-revoking-access#required-permissions',
      target: '_blank',
    });
  });

  it('renders text to update your_google_cloud_project_id', () => {
    expect(wrapper.text()).toContain(
      'Replace <your_google_cloud_project_id> with your Google Cloud project ID.',
    );
  });

  it('renders code instruction with copy button', () => {
    const instructions = `# Grant the Artifact Registry Reader role to GitLab users with at least the Guest role
gcloud projects add-iam-policy-binding '<your_google_cloud_project_id>' \\
  --member='principalSet://iam.googleapis.com/projects/1234/locations/global/workloadIdentityPools/testing/attribute.guest_access/true' \\
  --role='roles/artifactregistry.reader'

# Grant the Artifact Registry Writer role to GitLab users with at least the Developer role
gcloud projects add-iam-policy-binding '<your_google_cloud_project_id>' \\
  --member='principalSet://iam.googleapis.com/projects/1234/locations/global/workloadIdentityPools/testing/attribute.developer_access/true' \\
  --role='roles/artifactregistry.writer'`;

    expect(findClipboardButton().props()).toMatchObject({
      title: 'Copy command',
      text: instructions,
    });

    expect(findCodeBlockHighlighted().props()).toMatchObject({
      language: 'powershell',
      code: instructions,
    });
    expect(findCodeBlockHighlighted().attributes()).toMatchObject({
      tabindex: '0',
      role: 'group',
      'aria-label': 'Instructions',
    });
  });

  describe('when id is passed as prop', () => {
    beforeEach(() => {
      createComponent({ id: 'project-id' });
    });

    it('hides text to update your_google_cloud_project_id', () => {
      expect(wrapper.text()).not.toContain(
        'Replace <your_google_cloud_project_id> with your Google Cloud project ID.',
      );
    });

    it('renders code instruction with id passed', () => {
      expect(findCodeBlockHighlighted().props('code'))
        .toBe(`# Grant the Artifact Registry Reader role to GitLab users with at least the Guest role
gcloud projects add-iam-policy-binding project-id \\
  --member='principalSet://iam.googleapis.com/projects/1234/locations/global/workloadIdentityPools/testing/attribute.guest_access/true' \\
  --role='roles/artifactregistry.reader'

# Grant the Artifact Registry Writer role to GitLab users with at least the Developer role
gcloud projects add-iam-policy-binding project-id \\
  --member='principalSet://iam.googleapis.com/projects/1234/locations/global/workloadIdentityPools/testing/attribute.developer_access/true' \\
  --role='roles/artifactregistry.writer'`);
    });
  });
});
