import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/packages_and_registries/artifact_registry/setup/app.vue';
import SetupForm from 'ee/packages_and_registries/artifact_registry/setup/setup_form.vue';
import { CLIENT_BASE_URL, ORGANIZATION_GID } from '../mock_data';

// Both navigation helpers are stubbed, not only the one under assertion: a real
// `visitUrl` reaches jsdom navigation, which tears the environment down and buries
// whatever the assertion was going to say.
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
  visitUrlWithAlerts: jest.fn(),
}));

describe('ArtifactRegistrySetupApp', () => {
  let wrapper;

  const HANDLE = 'my-registry';
  const ORGANIZATION_PATH = 'gitlab-org';

  const MOCK_REGISTRY = {
    __typename: 'ArtifactRegistry',
    handle: HANDLE,
    status: 'active',
    createdAt: '2026-08-06T00:00:00Z',
  };

  const findSetupForm = () => wrapper.findComponent(SetupForm);
  const findHeading = () => wrapper.findComponent(PageHeading);
  const findDescription = () => wrapper.findByTestId('page-heading-description');

  const createComponent = () => {
    wrapper = shallowMountExtended(App, {
      provide: {
        organizationGid: ORGANIZATION_GID,
        organizationPath: ORGANIZATION_PATH,
        clientBaseUrl: CLIENT_BASE_URL,
      },
      stubs: { PageHeading },
    });
  };

  const claimHandle = async () => {
    findSetupForm().vm.$emit('success', MOCK_REGISTRY);
    await waitForPromises();
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the setup form, confirming nothing and sending the browser nowhere', () => {
    expect(findSetupForm().exists()).toBe(true);
    expect(visitUrlWithAlerts).not.toHaveBeenCalled();
  });

  it('names the page', () => {
    expect(findHeading().props('heading')).toBe('Set up Artifact registry');
  });

  it('says what the registry is and what it asks for', () => {
    expect(findDescription().text()).toBe(
      'A unified registry for artifacts across all projects and groups in your organization. To get started, choose a registry handle.',
    );
  });

  it('sends the browser to the new registry repositories route, carrying the confirmation', async () => {
    await claimHandle();

    expect(visitUrlWithAlerts).toHaveBeenCalledWith(
      '/o/gitlab-org/-/artifact_registry/my-registry/repositories',
      [
        {
          id: 'artifact-registry-activated',
          title: 'Artifact registry set up successfully',
          message: 'Create your first repository to start publishing and pulling artifacts.',
          variant: 'success',
          dismissible: true,
        },
      ],
    );
  });
});
