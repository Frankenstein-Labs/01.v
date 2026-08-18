import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DeleteRepositoryModal from 'ee/packages_and_registries/artifact_registry/repositories/components/delete_repository_modal.vue';
import RepositoryActions from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_actions.vue';
import SetupDrawer from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/setup_drawer.vue';
import { CLIENT_BASE_URL, SLUG, mockRepository } from '../../mock_data';

jest.mock('~/lib/utils/copy_to_clipboard');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('ArtifactRegistryRepositoryActions', () => {
  let wrapper;

  const mockToast = { show: jest.fn() };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findCopyItem = () => wrapper.findComponentByTestId('copy-repository-url');
  const findSetupItem = () => wrapper.findComponentByTestId('view-setup-instructions');
  const findDeleteItem = () => wrapper.findComponentByTestId('delete-repository');
  const findDeleteModal = () => wrapper.findComponent(DeleteRepositoryModal);
  const findSetupDrawer = () => wrapper.findComponent(SetupDrawer);

  const createComponent = (overrides = {}, provide = {}) => {
    wrapper = shallowMountExtended(RepositoryActions, {
      propsData: { repository: { ...mockRepository, ...overrides } },
      provide: { slug: SLUG, clientBaseUrl: CLIENT_BASE_URL, ...provide },
      mocks: { $toast: mockToast },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('names the repository in the toggle, which renders as an icon alone', () => {
    createComponent({ name: 'payment-core' });

    expect(findDropdown().props('toggleText')).toBe('More actions for payment-core');
  });

  it('renders the toggle as an icon-only tertiary button', () => {
    expect(findDropdown().props()).toMatchObject({
      icon: 'ellipsis_v',
      textSrOnly: true,
      category: 'tertiary',
      noCaret: true,
      placement: 'bottom-end',
    });
  });

  it('offers the read actions before the destructive one', () => {
    expect(findItems().wrappers.map((item) => item.props('item').text)).toEqual([
      'Copy repository URL',
      'View setup instructions',
      'Delete repository',
    ]);
  });

  // Copy reads and delete destroys, so copy comes first and delete is marked out.
  it('marks the delete action as destructive', () => {
    expect(findDeleteItem().props('item')).toMatchObject({
      text: 'Delete repository',
      variant: 'danger',
    });
  });

  describe('copying the repository URL', () => {
    it('copies the URL a client is pointed at for this repository and format', async () => {
      createComponent({ name: 'payment-core', format: 'NPM' });

      findCopyItem().props('item').action();
      await waitForPromises();

      expect(copyToClipboard).toHaveBeenCalledWith(`${CLIENT_BASE_URL}/${SLUG}/npm/payment-core`);
    });

    // A menu item shows nothing once it is chosen, so the toast is the only report that
    // the copy happened, and being a live region it is also the announcement.
    it('reports the copy through a toast', async () => {
      copyToClipboard.mockResolvedValue();

      findCopyItem().props('item').action();
      await waitForPromises();

      expect(mockToast.show).toHaveBeenCalledWith('Repository URL copied to clipboard.');
    });

    it('reports a failed copy rather than claiming it succeeded', async () => {
      const error = new Error('Clipboard write failed');
      copyToClipboard.mockRejectedValue(error);

      findCopyItem().props('item').action();
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
      expect(mockToast.show).not.toHaveBeenCalled();
    });

    // Nothing composes a URL without the Artifact Registry origin, which an instance
    // that has not configured the service does not have.
    it('is left out when no client base URL is provided', () => {
      createComponent({}, { clientBaseUrl: null });

      expect(findCopyItem().exists()).toBe(false);
      expect(findDeleteItem().exists()).toBe(true);
    });
  });

  describe('the setup drawer', () => {
    it('hands the drawer the repository it instructs for', () => {
      createComponent({ name: 'payment-core', format: 'NPM' });

      expect(findSetupDrawer().props()).toMatchObject({
        name: 'payment-core',
        format: 'NPM',
      });
    });

    it('stays closed until the action is chosen', () => {
      expect(findSetupDrawer().props('open')).toBe(false);
    });

    it('opens when the action is chosen', async () => {
      findSetupItem().props('item').action();
      await nextTick();

      expect(findSetupDrawer().props('open')).toBe(true);
    });

    it('closes again when the drawer reports it was dismissed', async () => {
      findSetupItem().props('item').action();
      await nextTick();

      findSetupDrawer().vm.$emit('close');
      await nextTick();

      expect(findSetupDrawer().props('open')).toBe(false);
    });

    it('is left out when no client base URL is provided', () => {
      createComponent({}, { clientBaseUrl: null });

      expect(findSetupItem().exists()).toBe(false);
    });
  });

  describe('the delete modal', () => {
    it('hands the repository to the modal', () => {
      expect(findDeleteModal().props('repository')).toStrictEqual(mockRepository);
    });

    it('stays closed until the action is chosen', () => {
      expect(findDeleteModal().props('visible')).toBe(false);
    });

    it('opens when the action is chosen', async () => {
      findDeleteItem().props('item').action();
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(true);
    });

    it('closes again when the modal reports it was dismissed', async () => {
      findDeleteItem().props('item').action();
      await nextTick();

      findDeleteModal().vm.$emit('change', false);
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(false);
    });
  });
});
