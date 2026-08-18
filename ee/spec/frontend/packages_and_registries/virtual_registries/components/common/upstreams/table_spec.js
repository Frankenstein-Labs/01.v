import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlSkeletonLoader,
  GlTable,
  GlTruncate,
} from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import MavenUpstreamsTable from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/table.vue';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/clear_cache_modal.vue';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/delete_modal.vue';
import deleteUpstreamCacheMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_upstream_cache.mutation.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { deleteMavenUpstreamCache } from 'ee/api/virtual_registries_api';
import { groupMavenUpstreams } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils', () => ({
  captureException: jest.fn(),
}));
jest.mock('ee/api/virtual_registries_api', () => ({
  deleteMavenUpstreamCache: jest.fn(),
}));

Vue.use(VueApollo);

describe('Virtual registries upstreams table', () => {
  let wrapper;

  const defaultProps = {
    upstreams: groupMavenUpstreams.group.upstreams.nodes,
    busy: false,
  };

  const defaultProvide = {
    editUpstreamPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/:id/edit',
    showUpstreamPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/:id',
    routes: {
      editUpstreamRouteName: 'UPSTREAM_EDIT',
      showUpstreamRouteName: 'UPSTREAM_SHOW',
    },
    glAbilities: {
      updateVirtualRegistry: true,
    },
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUpstreamLinks = () => wrapper.findAllComponentsByTestId('upstream-name');
  const findEditButtons = () => wrapper.findAllComponentsByTestId('edit-upstream-button');
  const findClearCacheButtons = () => wrapper.findAllComponentsByTestId('clear-cache-button');
  const findMoreActionDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findTruncateComponents = () => wrapper.findAllComponents(GlTruncate);
  const findUpstreamClearCacheModal = () => wrapper.findComponent(UpstreamClearCacheModal);
  const findUpstreamDeleteModal = () => wrapper.findComponent(DeleteUpstreamWithModal);
  const findCacheValidityHoursElement = () => wrapper.findByTestId('cache-validity-hours');
  const findMetadataCacheValidityHoursElement = () =>
    wrapper.findByTestId('metadata-cache-validity-hours');

  const showToastSpy = jest.fn();

  const createComponent = ({ props = {}, provide = {}, deleteCacheHandler = null } = {}) => {
    const apolloProvider = createMockApollo([[deleteUpstreamCacheMutation, deleteCacheHandler]]);

    wrapper = mountExtended(MavenUpstreamsTable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        DeleteUpstreamWithModal: true,
      },
      mocks: {
        $toast: {
          show: showToastSpy,
        },
      },
      apolloProvider,
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the table with correct props', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'name',
          label: 'Upstream',
          tdClass: '@sm/panel:gl-max-w-0',
        },
        {
          key: 'registriesCount',
          label: 'Used by registries',
          tdClass: '@sm/panel:gl-w-20 @sm/panel:!gl-leading-32',
        },
        {
          key: 'actions',
          label: 'Actions',
          hide: false,
          thAlignRight: true,
          thClass: 'gl-w-26',
          tdClass: 'gl-text-right',
        },
      ]);
    });

    it('renders upstream names as links with router navigation', () => {
      const links = findUpstreamLinks();

      expect(links).toHaveLength(2);
      expect(links.at(0).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/upstreams/1',
      );
      expect(links.at(0).props('to')).toEqual({
        name: 'UPSTREAM_SHOW',
        params: { id: 1 },
      });
      expect(links.at(1).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/upstreams/2',
      );
      expect(links.at(1).props('to')).toEqual({
        name: 'UPSTREAM_SHOW',
        params: { id: 2 },
      });
    });

    it('renders upstream names and URLs with truncation', () => {
      const truncateComponents = findTruncateComponents();

      expect(truncateComponents.at(0).props()).toMatchObject({
        text: 'Maven Central',
        withTooltip: true,
      });
      expect(truncateComponents.at(1).props()).toMatchObject({
        text: 'https://repo1.maven.org/maven2/',
        withTooltip: true,
      });
    });

    it('displays cache validity hours correctly', () => {
      expect(findCacheValidityHoursElement().text()).toBe('Artifact cache: 24 hours');
    });

    it('displays metadata cache validity hours correctly', () => {
      expect(findMetadataCacheValidityHoursElement().text()).toBe('Metadata cache: 12 hours');
    });

    it('renders clear cache button when user has permission', () => {
      const clearCacheButtons = findClearCacheButtons();

      expect(clearCacheButtons).toHaveLength(2);
      expect(clearCacheButtons.at(0).props()).toMatchObject({
        size: 'small',
        category: 'tertiary',
      });
      expect(clearCacheButtons.at(0).text()).toBe('Clear cache');
    });

    it('renders edit button link when user has permission with router navigation', () => {
      const editButtons = findEditButtons();

      expect(editButtons).toHaveLength(2);
      expect(editButtons.at(0).props()).toMatchObject({
        size: 'small',
        category: 'tertiary',
        icon: 'pencil',
        href: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/1/edit',
      });
      expect(editButtons.at(0).props('to')).toEqual({
        name: 'UPSTREAM_EDIT',
        params: { id: 1 },
      });
      expect(editButtons.at(0).attributes('aria-label')).toBe('Edit upstream Maven Central');
    });

    it('renders More actions dropdown', () => {
      const moreActionDropdowns = findMoreActionDropdowns();

      expect(moreActionDropdowns).toHaveLength(2);
      expect(moreActionDropdowns.at(0).props()).toMatchObject({
        textSrOnly: true,
        category: 'tertiary',
        icon: 'ellipsis_v',
        toggleText: 'More actions',
      });

      const dropdownItem = moreActionDropdowns.at(0).findComponent(GlDisclosureDropdownItem);
      expect(dropdownItem.text()).toBe('Delete upstream');
    });

    describe('when user lacks permissions', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glAbilities: {
              updateVirtualRegistry: false,
            },
          },
        });
      });

      it('does not render action buttons', () => {
        expect(findClearCacheButtons()).toHaveLength(0);
        expect(findEditButtons()).toHaveLength(0);
        expect(findMoreActionDropdowns()).toHaveLength(0);
      });

      it('hides the table action column', () => {
        expect(findTable().props('fields')).toEqual([
          {
            key: 'name',
            label: 'Upstream',
            tdClass: '@sm/panel:gl-max-w-0',
          },
          {
            key: 'registriesCount',
            label: 'Used by registries',
            tdClass: '@sm/panel:gl-w-20 @sm/panel:!gl-leading-32',
          },
        ]);
      });
    });

    it('does not render upstream clear cache modal', () => {
      expect(findUpstreamClearCacheModal().props()).toStrictEqual({
        visible: false,
        upstreamName: '',
      });
    });

    it('does not render upstream delete modal', () => {
      expect(findUpstreamDeleteModal().props()).toStrictEqual({
        visible: false,
        upstreamId: null,
        upstreamName: '',
      });
    });
  });

  describe('when busy', () => {
    beforeEach(() => {
      createComponent({ props: { busy: true } });
    });

    it('shows skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('cache validity labels', () => {
    it('handles singular hour correctly', () => {
      createComponent({
        props: {
          upstreams: [
            {
              id: 1,
              name: 'Test',
              url: 'https://test.com',
              cacheValidityHours: 1,
              metadataCacheValidityHours: 1,
            },
          ],
        },
      });

      expect(findCacheValidityHoursElement().text()).toBe('Artifact cache: 1 hour');
      expect(findMetadataCacheValidityHoursElement().text()).toBe('Metadata cache: 1 hour');
    });
  });

  describe('clear upstream cache action', () => {
    describe('with REST API', () => {
      beforeEach(() => {
        deleteMavenUpstreamCache.mockReset();
        showToastSpy.mockReset();
      });

      it('shows modal when clear cache button is clicked', async () => {
        createComponent();

        await findClearCacheButtons().at(0).vm.$emit('click');

        expect(findUpstreamClearCacheModal().props()).toStrictEqual({
          visible: true,
          upstreamName: 'Maven Central',
        });
      });

      it('hides modal when canceled', async () => {
        createComponent();

        await findClearCacheButtons().at(0).vm.$emit('click');
        await findUpstreamClearCacheModal().vm.$emit('canceled');

        expect(findUpstreamClearCacheModal().props()).toStrictEqual({
          visible: false,
          upstreamName: '',
        });
      });

      describe('when API succeeds', () => {
        beforeEach(() => {
          deleteMavenUpstreamCache.mockResolvedValue();
          createComponent();
        });

        it('calls API with correct parameters and shows success toast', async () => {
          await findClearCacheButtons().at(0).vm.$emit('click');
          await findUpstreamClearCacheModal().vm.$emit('primary');

          expect(deleteMavenUpstreamCache).toHaveBeenCalledWith({ id: 1 });

          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith('Upstream cache cleared successfully.');
          expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when API fails', () => {
        it('shows error message', async () => {
          const mockError = new Error('API Error');
          deleteMavenUpstreamCache.mockRejectedValue(mockError);

          createComponent();

          await findClearCacheButtons().at(0).vm.$emit('click');
          await findUpstreamClearCacheModal().vm.$emit('primary');

          await waitForPromises();

          expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
          expect(showToastSpy).toHaveBeenCalledWith('Failed to clear upstream cache. Try again.');
          expect(captureException).toHaveBeenCalledWith({
            error: mockError,
            component: 'UpstreamsTable',
          });
        });
      });
    });

    describe('with GraphQL mutation', () => {
      let deleteCacheHandler;

      beforeEach(() => {
        deleteCacheHandler = jest.fn().mockResolvedValue({ data: { cacheDelete: { errors: [] } } });
        showToastSpy.mockReset();
      });

      it('shows modal when clear cache button is clicked', async () => {
        createComponent({ provide: { deleteUpstreamCacheMutation }, deleteCacheHandler });

        await findClearCacheButtons().at(0).vm.$emit('click');

        expect(findUpstreamClearCacheModal().props()).toStrictEqual({
          visible: true,
          upstreamName: 'Maven Central',
        });
      });

      it('hides modal when canceled', async () => {
        createComponent({ provide: { deleteUpstreamCacheMutation }, deleteCacheHandler });

        await findClearCacheButtons().at(0).vm.$emit('click');
        await findUpstreamClearCacheModal().vm.$emit('canceled');

        expect(findUpstreamClearCacheModal().props()).toStrictEqual({
          visible: false,
          upstreamName: '',
        });
      });

      describe('when API succeeds', () => {
        beforeEach(() => {
          createComponent({ provide: { deleteUpstreamCacheMutation }, deleteCacheHandler });
        });

        it('calls API with correct parameters and shows success toast', async () => {
          await findClearCacheButtons().at(0).vm.$emit('click');
          await findUpstreamClearCacheModal().vm.$emit('primary');

          expect(deleteCacheHandler).toHaveBeenCalledWith({
            id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
          });

          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith('Upstream cache cleared successfully.');
          expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when API fails', () => {
        it('with mutation error shows error message', async () => {
          createComponent({
            provide: { deleteUpstreamCacheMutation },
            deleteCacheHandler: jest.fn().mockResolvedValue({
              data: { cacheDelete: { errors: ['error'] } },
            }),
          });

          await findClearCacheButtons().at(0).vm.$emit('click');
          await findUpstreamClearCacheModal().vm.$emit('primary');

          await waitForPromises();

          expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
          expect(showToastSpy).toHaveBeenCalledWith('Failed to clear upstream cache. Try again.');
          expect(captureException).toHaveBeenCalledWith({
            error: ['error'],
            component: 'UpstreamsTable',
          });
        });

        it('with server error shows error message', async () => {
          const mockError = new Error('API Error');

          createComponent({
            provide: { deleteUpstreamCacheMutation },
            deleteCacheHandler: jest.fn().mockRejectedValue(mockError),
          });

          await findClearCacheButtons().at(0).vm.$emit('click');
          await findUpstreamClearCacheModal().vm.$emit('primary');

          await waitForPromises();

          expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
          expect(showToastSpy).toHaveBeenCalledWith('Failed to clear upstream cache. Try again.');
          expect(captureException).toHaveBeenCalledWith({
            error: mockError,
            component: 'UpstreamsTable',
          });
        });
      });
    });
  });

  describe('delete upstream action', () => {
    beforeEach(() => {
      createComponent();
    });
    const findDropdownItem = () =>
      findMoreActionDropdowns().at(0).findComponent(GlDisclosureDropdownItem);

    it('shows modal when `Delete upstream` dropdown item is clicked', async () => {
      await findDropdownItem().vm.$emit('action');

      expect(findUpstreamDeleteModal().props()).toStrictEqual({
        visible: true,
        upstreamName: 'Maven Central',
        upstreamId: 1,
      });
    });

    it('hides modal when canceled', async () => {
      await findDropdownItem().vm.$emit('action');
      await findUpstreamDeleteModal().vm.$emit('canceled');

      expect(findUpstreamDeleteModal().props()).toStrictEqual({
        visible: false,
        upstreamName: '',
        upstreamId: null,
      });
    });

    describe('when modal emits success', () => {
      it('emits `upstream-deleted` event and hides the modal', async () => {
        await findDropdownItem().vm.$emit('action');
        await findUpstreamDeleteModal().vm.$emit('success');

        expect(wrapper.emitted('upstream-deleted')).toHaveLength(1);
        expect(findUpstreamDeleteModal().props('visible')).toBe(false);
      });
    });

    describe('when modal emits error', () => {
      it('emits `upstream-delete-failed` event with parsed error message and hides the modal', async () => {
        const mockError = new Error('API Error');

        await findDropdownItem().vm.$emit('action');
        await findUpstreamDeleteModal().vm.$emit('error', mockError);

        expect(wrapper.emitted('upstream-delete-failed')).toHaveLength(1);
        expect(wrapper.emitted('upstream-delete-failed')[0][0]).toBe('API Error');
        expect(findUpstreamDeleteModal().props('visible')).toBe(false);
      });

      it('emits `upstream-delete-failed` event with parsed GraphQL error messages and hides the modal', async () => {
        await findDropdownItem().vm.$emit('action');
        await findUpstreamDeleteModal().vm.$emit('error', {
          response: { data: { delete: { errors: ['API Error', 'Error!'] } } },
        });

        expect(wrapper.emitted('upstream-delete-failed')).toHaveLength(1);
        expect(wrapper.emitted('upstream-delete-failed')[0][0]).toBe('API Error, Error!');
        expect(findUpstreamDeleteModal().props('visible')).toBe(false);
      });
    });
  });
});
