import { GlEmptyState } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NotFound from 'ee/packages_and_registries/artifact_registry/components/not_found.vue';

describe('ArtifactRegistryRepositoriesNotFound', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  beforeEach(() => {
    wrapper = shallowMountExtended(NotFound);
  });

  it('renders a level-1 empty state with the not-found title and description', () => {
    expect(findEmptyState().props()).toMatchObject({
      title: 'Page not found',
      description: 'Make sure the address is correct and the page has not moved.',
      headerLevel: 1,
    });
  });
});
