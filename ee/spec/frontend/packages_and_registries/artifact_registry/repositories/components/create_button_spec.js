import { GlDisclosureDropdown } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { REPOSITORY_NEW_HOSTED_ROUTE_NAME } from 'ee/packages_and_registries/artifact_registry/constants';
import CreateButton from 'ee/packages_and_registries/artifact_registry/repositories/components/create_button.vue';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import { BASE_PATH } from '../../mock_data';

describe('ArtifactRegistryCreateButton', () => {
  let wrapper;

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findHostedEntry = () => wrapper.findByRole('link', { name: 'Hosted repository' });

  const createComponent = async ({ mountFn = shallowMountExtended } = {}) => {
    const router = createRouter(BASE_PATH);
    await router.push('/');

    wrapper = mountFn(CreateButton, { router });
  };

  beforeEach(async () => {
    await createComponent();
  });

  it('reads as the primary action on the page it sits on', () => {
    expect(findDropdown().props()).toMatchObject({
      variant: 'confirm',
      placement: 'bottom-end',
    });
  });

  it('names what it creates, so the toggle stands alone as an accessible name', () => {
    expect(findDropdown().props('toggleText')).toBe('New repository');
  });

  it('offers hosted alone, because Artifact Registry accepts no other kind yet', () => {
    expect(findDropdown().props('items')).toEqual([
      { text: 'Hosted repository', to: { name: REPOSITORY_NEW_HOSTED_ROUTE_NAME } },
    ]);
  });

  it('renders the entry as a link, so choosing a kind reads as navigation', async () => {
    await createComponent({ mountFn: mountExtended });

    expect(findHostedEntry().attributes('href')).toBe(`${BASE_PATH}/new/hosted`);
  });
});
