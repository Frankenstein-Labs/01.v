import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CreateButton from 'ee/packages_and_registries/artifact_registry/repositories/components/create_button.vue';
import RepositoriesHeader from 'ee/packages_and_registries/artifact_registry/repositories/list/repositories_header.vue';

describe('ArtifactRegistryRepositoriesHeader', () => {
  let wrapper;

  const findHeading = () => wrapper.findComponent(PageHeading);
  const findCreateButton = () =>
    wrapper.findByTestId('page-heading-actions').findComponent(CreateButton);

  beforeEach(() => {
    // The heading is unstubbed so its actions slot renders, which is where the create
    // entry has to land rather than anywhere else in the header.
    wrapper = shallowMountExtended(RepositoriesHeader, { stubs: { PageHeading } });
  });

  it('names the view in the page-level heading', () => {
    expect(findHeading().props('heading')).toBe('Repositories');
  });

  it('renders the create entry beside the heading', () => {
    expect(findCreateButton().exists()).toBe(true);
  });
});
