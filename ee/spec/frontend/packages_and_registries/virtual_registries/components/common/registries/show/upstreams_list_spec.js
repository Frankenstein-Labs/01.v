import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlBadge } from '@gitlab/ui';
import mavenRegistryUpstreamsFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql.json';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistryDetailsUpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/upstreams_list.vue';
import AddUpstream from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/add_upstream.vue';
import LinkUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/link_upstream_form.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/registry_upstream_item.vue';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/form.vue';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/clear_cache_modal.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import getMavenUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import createUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_maven_upstream.mutation.graphql';
import deleteRegistryCacheMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_registry_cache.mutation.graphql';
import deleteUpstreamCacheMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_upstream_cache.mutation.graphql';
import createRegistryUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_container_registry_upstream.mutation.graphql';
import deleteRegistryUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_registry_upstream.mutation.graphql';
import updateRegistryUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/update_container_registry_upstream.mutation.graphql';
import {
  associateMavenUpstreamWithVirtualRegistry,
  deleteMavenUpstreamCache,
  deleteMavenRegistryCache,
  removeMavenUpstreamRegistryAssociation,
  updateMavenRegistryUpstreamPosition,
} from 'ee/api/virtual_registries_api';
import { groupMavenUpstreamsCount } from 'ee_jest/packages_and_registries/virtual_registries/mock_data';

jest.mock('ee/api/virtual_registries_api');
jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('MavenRegistryDetailsUpstreamsList', () => {
  let wrapper;

  const { registry } = mavenRegistryUpstreamsFixture.data;
  const { registryUpstreams } = registry;
  const [registryUpstream] = registryUpstreams;

  const defaultProps = {
    id: registry.id,
    registryUpstreams,
  };

  const defaultProvide = {
    glAbilities: {
      createVirtualRegistry: true,
      updateVirtualRegistry: true,
    },
    fullPath: 'full-path',
    getUpstreamsCountQuery: getMavenUpstreamsCountQuery,
    ids: {
      baseRegistry: 'VirtualRegistries::Packages::Maven::Registry',
    },
    isMavenUpstream: true,
    createUpstreamMutation,
    maxRegistryUpstreamsCount: 20,
  };

  const expectedCapture = (error) => {
    return {
      component: 'RegistryShowUpstreamsList',
      error,
    };
  };

  const getUpstreamsCountHandler = jest
    .fn()
    .mockResolvedValue({ data: { ...groupMavenUpstreamsCount } });

  const createUpstreamSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      createUpstream: {
        upstream: {
          id: 7,
          description: '',
          ...registryUpstream.upstream,
        },
        errors: [],
      },
    },
  });

  const mockGraphQLError = new Error('GraphQL error');

  const createUpstreamErrorHandler = jest.fn().mockResolvedValue({
    data: {
      createUpstream: {
        upstream: null,
        errors: ['Name too long'],
      },
    },
  });

  const errorHandler = jest.fn().mockRejectedValue(mockGraphQLError);
  const showToastSpy = jest.fn();

  const findAddUpstream = () => wrapper.findComponent(AddUpstream);
  const findClearRegistryCacheButton = () =>
    wrapper.findComponentByTestId('clear-registry-cache-button');
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findClearRegistryCacheModal = () =>
    wrapper.findComponentByTestId('clear-registry-cache-modal');
  const findUpstreamClearCacheModal = () => wrapper.findComponent(UpstreamClearCacheModal);
  const findCreateUpstreamForm = () => wrapper.findComponent(RegistryUpstreamForm);
  const findLinkUpstreamForm = () => wrapper.findComponent(LinkUpstreamForm);
  const findCreateUpstreamErrorAlert = () => wrapper.findComponent(GlAlert);
  const findUpstreamItems = () => wrapper.findAllComponents(RegistryUpstreamItem);
  const findUpdateActionErrorAlert = () => wrapper.findByTestId('update-action-error-alert');
  const findUpstreamsCountBadge = () => wrapper.findComponent(GlBadge);
  const findMaxUpstreamsMessage = () => wrapper.findByTestId('max-upstreams');

  const mockDeleteRegistryCache = jest
    .fn()
    .mockResolvedValue({ data: { registryCacheDelete: { errors: [] } } });
  const mockDeleteUpstreamCache = jest
    .fn()
    .mockResolvedValue({ data: { cacheDelete: { errors: [] } } });
  const mockCreateRegistryUpstream = jest
    .fn()
    .mockResolvedValue({ data: { upstreamCreate: { errors: [] } } });
  const mockDeleteRegistryUpstream = jest
    .fn()
    .mockResolvedValue({ data: { upstreamDelete: { errors: [] } } });
  const mockUpdateRegistryUpstream = jest
    .fn()
    .mockResolvedValue({ data: { update: { errors: [] } } });

  const createComponent = ({
    provide = {},
    props = {},
    glAbilities = {},
    mutationHandler = createUpstreamSuccessHandler,
    deleteRegistryCacheHandler = mockDeleteRegistryCache,
    deleteUpstreamCacheHandler = mockDeleteUpstreamCache,
    createRegistryUpstreamHandler = mockCreateRegistryUpstream,
    deleteRegistryUpstreamHandler = mockDeleteRegistryUpstream,
    updateRegistryUpstreamHandler = mockUpdateRegistryUpstream,
    stubs = {},
  } = {}) => {
    const handlers = [
      [getMavenUpstreamsCountQuery, getUpstreamsCountHandler],
      [createUpstreamMutation, mutationHandler],
      [deleteRegistryCacheMutation, deleteRegistryCacheHandler],
      [deleteUpstreamCacheMutation, deleteUpstreamCacheHandler],
      [createRegistryUpstreamMutation, createRegistryUpstreamHandler],
      [deleteRegistryUpstreamMutation, deleteRegistryUpstreamHandler],
      [updateRegistryUpstreamMutation, updateRegistryUpstreamHandler],
    ];

    wrapper = shallowMountExtended(MavenRegistryDetailsUpstreamsList, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        glAbilities: {
          ...defaultProvide.glAbilities,
          ...glAbilities,
        },
        ...provide,
      },
      stubs: {
        CrudComponent,
        ...stubs,
      },
      mocks: {
        $toast: {
          show: showToastSpy,
        },
      },
    });
  };

  it('sets components to loading', () => {
    createComponent({ props: { loading: true } });

    expect(findCrudComponent().props('isLoading')).toBe(true);
    expect(findAddUpstream().props('loading')).toBe(true);
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls getMavenUpstreamsCount query', () => {
      expect(getUpstreamsCountHandler).toHaveBeenCalledWith({ groupPath: 'full-path' });
    });

    it('renders the Crud component with correct props', () => {
      expect(findCrudComponent().props()).toMatchObject({
        title: 'Upstreams',
        isLoading: false,
      });
    });

    it('renders upstreams count badge with correct text', () => {
      expect(findUpstreamsCountBadge().text()).toBe('4 of 20');
    });

    it('renders `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(true);
    });

    it('renders AddUpstreamAction component with `canLink` set to false', () => {
      expect(findAddUpstream().props('canLink')).toBe(false);
    });

    it('does not show max upstreams message when limit not reached', () => {
      expect(findMaxUpstreamsMessage().exists()).toBe(false);
    });

    it('renders the upstreams and passes correct props to each', () => {
      const upstreamItems = findUpstreamItems();

      expect(upstreamItems).toHaveLength(registryUpstreams.length);
      expect(upstreamItems.at(0).props()).toMatchObject({
        registryUpstream,
      });
    });

    describe('when AddUpstreamAction component emits create event', () => {
      beforeEach(() => {
        findAddUpstream().vm.$emit('create');
      });

      it('shows create upstream form', () => {
        expect(findCreateUpstreamForm().exists()).toBe(true);
        expect(findLinkUpstreamForm().exists()).toBe(false);
        expect(findAddUpstream().props('disabled')).toBe(true);
      });

      it('hides create form when form emits cancel event', async () => {
        await findCreateUpstreamForm().vm.$emit('cancel');

        expect(findCreateUpstreamForm().exists()).toBe(false);
        expect(findAddUpstream().props('disabled')).toBe(false);
      });
    });

    it('hides the registry clear cache modal', () => {
      expect(findClearRegistryCacheModal().props('visible')).toBe(false);
    });

    it('hides the upstream clear cache modal', () => {
      expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
    });
  });

  describe('when user does not have ability to create', () => {
    beforeEach(() => {
      createComponent({
        glAbilities: { createVirtualRegistry: false },
      });
    });

    it('does not render AddUpstreamAction component', () => {
      expect(findAddUpstream().exists()).toBe(false);
    });
  });

  describe('when user does not have ability to update', () => {
    beforeEach(() => {
      createComponent({
        glAbilities: { updateVirtualRegistry: false },
      });
    });

    it('does not call getMavenUpstreamsCount query', () => {
      expect(getUpstreamsCountHandler).not.toHaveBeenCalled();
    });

    it('does not show `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(false);
    });

    it('renders AddUpstreamAction component with `canLink` set to false', () => {
      expect(findAddUpstream().props('canLink')).toBe(false);
    });
  });

  describe('when there are group level upstreams & registry has no upstreams', () => {
    beforeEach(async () => {
      createComponent({
        props: {
          registryUpstreams: [],
        },
      });
      await waitForPromises();
    });

    it('does not show `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(false);
    });

    it('renders AddUpstreamAction component with `canLink` set to true', () => {
      expect(findAddUpstream().props('canLink')).toBe(true);
    });

    describe('when AddUpstreamAction component emits link event', () => {
      beforeEach(() => {
        findAddUpstream().vm.$emit('link');
      });

      it('shows link form', () => {
        expect(findLinkUpstreamForm().props('linkedUpstreamIds')).toStrictEqual([]);
        expect(findCreateUpstreamForm().exists()).toBe(false);
        expect(findAddUpstream().props('disabled')).toBe(true);
      });

      it('hides create form when form emits cancel event', async () => {
        await findLinkUpstreamForm().vm.$emit('cancel');

        expect(findLinkUpstreamForm().exists()).toBe(false);
        expect(findAddUpstream().props('disabled')).toBe(false);
      });
    });
  });

  describe('when there are group level upstreams & registry has upstreams', () => {
    beforeEach(async () => {
      createComponent({
        props: {
          registryUpstreams,
        },
      });
      await waitForPromises();
    });

    it('renders AddUpstreamAction component with `canLink` set to true', () => {
      expect(findAddUpstream().props('canLink')).toBe(true);
    });

    it('when link form is shown, sets the upstream options correctly', async () => {
      await findAddUpstream().vm.$emit('link');

      expect(findLinkUpstreamForm().props('linkedUpstreamIds')).toStrictEqual(
        registryUpstreams.map(({ upstream }) => upstream.id),
      );
    });
  });

  describe('create upstream action', () => {
    const upstream = {
      name: 'Maven upstream 7',
      url: 'https://repo.maven.apache.org/maven2',
      description: '',
      username: '',
      password: '',
      cacheValidityHours: 24,
      metadataCacheValidityHours: 24,
    };

    it('emits `update` on successful form submission', async () => {
      createComponent({
        mutationHandler: createUpstreamSuccessHandler,
      });

      await findAddUpstream().vm.$emit('create');

      await findCreateUpstreamForm().vm.$emit('submit', upstream);

      expect(findCreateUpstreamForm().props('loading')).toBe(true);

      await waitForPromises();

      expect(createUpstreamSuccessHandler).toHaveBeenCalledWith({
        id: registry.id,
        ...upstream,
      });
      expect(findCreateUpstreamForm().exists()).toBe(false);
      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(showToastSpy).toHaveBeenCalledWith('Upstream created successfully.');
      expect(findCreateUpstreamErrorAlert().exists()).toBe(false);
      expect(captureException).not.toHaveBeenCalled();
    });

    describe('with errors', () => {
      it('renders alert with message', async () => {
        createComponent({
          mutationHandler: createUpstreamErrorHandler,
        });

        await findAddUpstream().vm.$emit('create');

        await findCreateUpstreamForm().vm.$emit('submit', upstream);

        expect(findCreateUpstreamForm().props('loading')).toBe(true);

        await waitForPromises();

        expect(findCreateUpstreamForm().props('loading')).toBe(false);
        expect(findCreateUpstreamErrorAlert().text()).toBe('Name too long');
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).not.toHaveBeenCalled();
      });

      it('sends an error to Sentry', async () => {
        createComponent({
          mutationHandler: errorHandler,
        });

        await findAddUpstream().vm.$emit('create');

        await findCreateUpstreamForm().vm.$emit('submit', upstream);

        await waitForPromises();

        expect(findCreateUpstreamErrorAlert().text()).toBe(
          'Something went wrong while creating the upstream. Try again.',
        );
        expect(findCreateUpstreamForm().props('loading')).toBe(false);
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
      });
    });
  });

  describe('link upstream action', () => {
    const upstreamId = 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/3';

    beforeEach(() => {
      associateMavenUpstreamWithVirtualRegistry.mockReset();
    });

    describe('when using REST API', () => {
      describe('when succeeds', () => {
        beforeEach(async () => {
          associateMavenUpstreamWithVirtualRegistry.mockResolvedValue();
          createComponent();
          await findAddUpstream().vm.$emit('link');
          findLinkUpstreamForm().vm.$emit('submit', upstreamId);
        });

        it('calls the right arguments', () => {
          expect(associateMavenUpstreamWithVirtualRegistry).toHaveBeenCalledWith({
            registryId: getIdFromGraphQLId(registry.id),
            upstreamId: getIdFromGraphQLId(upstreamId),
          });
        });

        it('shows success toast and emits `update` event', async () => {
          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith(
            'Upstream added to virtual registry successfully.',
          );
          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when fails', () => {
        it('shows toast with default message & reports error to Sentry', async () => {
          const mockError = new Error();
          associateMavenUpstreamWithVirtualRegistry.mockRejectedValue(mockError);
          createComponent();
          await findAddUpstream().vm.$emit('link');

          findLinkUpstreamForm().vm.$emit('submit', upstreamId);

          await waitForPromises();

          expect(findCreateUpstreamErrorAlert().text()).toBe(
            'Something went wrong while adding the upstream to virtual registry. Try again.',
          );
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
        });
      });
    });

    describe('when using GraphQL API', () => {
      describe('when succeeds', () => {
        beforeEach(async () => {
          createComponent({
            provide: { createRegistryUpstreamMutation },
          });
          await findAddUpstream().vm.$emit('link');
          findLinkUpstreamForm().vm.$emit('submit', upstreamId);
        });

        it('calls the mutation with the right arguments', () => {
          expect(mockCreateRegistryUpstream).toHaveBeenCalledWith({
            registryId: registry.id,
            upstreamId,
          });
        });

        it('does not call the REST API', () => {
          expect(associateMavenUpstreamWithVirtualRegistry).not.toHaveBeenCalled();
        });

        it('shows success toast and emits `update` event', async () => {
          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith(
            'Upstream added to virtual registry successfully.',
          );
          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when fails', () => {
        it('with mutation error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { createRegistryUpstreamMutation },
            createRegistryUpstreamHandler: jest
              .fn()
              .mockResolvedValue({ data: { upstreamCreate: { errors: ['some error'] } } }),
          });
          await findAddUpstream().vm.$emit('link');

          findLinkUpstreamForm().vm.$emit('submit', upstreamId);

          await waitForPromises();

          expect(findCreateUpstreamErrorAlert().text()).toBe(
            'Something went wrong while adding the upstream to virtual registry. Try again.',
          );
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture('some error'));
        });

        it('with server error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { createRegistryUpstreamMutation },
            createRegistryUpstreamHandler: errorHandler,
          });
          await findAddUpstream().vm.$emit('link');

          findLinkUpstreamForm().vm.$emit('submit', upstreamId);

          await waitForPromises();

          expect(findCreateUpstreamErrorAlert().text()).toBe(
            'Something went wrong while adding the upstream to virtual registry. Try again.',
          );
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
        });
      });
    });
  });

  describe('update upstream position action', () => {
    beforeEach(() => {
      updateMavenRegistryUpstreamPosition.mockReset();
    });

    describe('when using REST API', () => {
      describe('when API succeeds', () => {
        beforeEach(() => {
          updateMavenRegistryUpstreamPosition.mockResolvedValue();
          createComponent();
        });

        it('when direction is `down` calculates the right position', () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          expect(updateMavenRegistryUpstreamPosition).toHaveBeenCalledWith({
            id: getIdFromGraphQLId(registryUpstream.id),
            position: 2,
          });
        });

        it('when direction is `up`, calculates the right position', () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(1).vm.$emit('reorder-upstream', 'up', registryUpstreams[1]);

          expect(updateMavenRegistryUpstreamPosition).toHaveBeenCalledWith({
            id: getIdFromGraphQLId(registryUpstreams[1].id),
            position: 1,
          });
        });

        it('emits `update` event when successful', async () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(1).vm.$emit('reorder-upstream', 'up', registryUpstreams[1]);

          await waitForPromises();

          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(showToastSpy).toHaveBeenCalledWith(
            'Position of the upstream has been updated successfully.',
          );
          expect(findUpdateActionErrorAlert().exists()).toBe(false);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when API fails', () => {
        it('shows alert with message & reports error to Sentry', async () => {
          const mockError = { error: 'position does not have a valid value' };
          updateMavenRegistryUpstreamPosition.mockRejectedValue(mockError);
          createComponent();

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'up', registryUpstream);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe('position does not have a valid value');
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
        });

        it('shows alert with default message & reports error to Sentry', async () => {
          const mockError = new Error();
          updateMavenRegistryUpstreamPosition.mockRejectedValue(mockError);
          createComponent();

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe(
            'Failed to update position of the upstream. Try again.',
          );
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
        });
      });
    });

    describe('when using GraphQL API', () => {
      describe('when succeeds', () => {
        beforeEach(() => {
          createComponent({
            provide: { updateRegistryUpstreamMutation },
          });
        });

        it('when direction is `down` calls the mutation with the right arguments', () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          expect(mockUpdateRegistryUpstream).toHaveBeenCalledWith({
            id: registryUpstream.id,
            position: 2,
          });
        });

        it('when direction is `up` calls the mutation with the right arguments', () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(1).vm.$emit('reorder-upstream', 'up', registryUpstreams[1]);

          expect(mockUpdateRegistryUpstream).toHaveBeenCalledWith({
            id: registryUpstreams[1].id,
            position: 1,
          });
        });

        it('does not call the REST API', () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          expect(updateMavenRegistryUpstreamPosition).not.toHaveBeenCalled();
        });

        it('emits `update` event when successful', async () => {
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(1).vm.$emit('reorder-upstream', 'up', registryUpstreams[1]);

          await waitForPromises();

          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(showToastSpy).toHaveBeenCalledWith(
            'Position of the upstream has been updated successfully.',
          );
          expect(findUpdateActionErrorAlert().exists()).toBe(false);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when fails', () => {
        it('with mutation error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { updateRegistryUpstreamMutation },
            updateRegistryUpstreamHandler: jest
              .fn()
              .mockResolvedValue({ data: { update: { errors: ['position is invalid'] } } }),
          });

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe('position is invalid');
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture('position is invalid'));
        });

        it('with server error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { updateRegistryUpstreamMutation },
            updateRegistryUpstreamHandler: errorHandler,
          });

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('reorder-upstream', 'down', registryUpstream);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe(
            'Failed to update position of the upstream. Try again.',
          );
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
        });
      });
    });
  });

  describe('remove upstream action', () => {
    const registryUpstreamAssociationId = registryUpstream.id;
    beforeEach(() => {
      removeMavenUpstreamRegistryAssociation.mockReset();
    });

    describe('when using REST API', () => {
      describe('when succeeds', () => {
        beforeEach(() => {
          removeMavenUpstreamRegistryAssociation.mockResolvedValue();
          createComponent();
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('remove-upstream', registryUpstreamAssociationId);
        });

        it('calls the right arguments', () => {
          expect(removeMavenUpstreamRegistryAssociation).toHaveBeenCalledWith({
            id: getIdFromGraphQLId(registryUpstreamAssociationId),
          });
        });

        it('shows success toast and emits `update` event', async () => {
          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith('Removed upstream from virtual registry.');
          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when fails', () => {
        it('shows toast with default message & reports error to Sentry', async () => {
          const mockError = new Error();
          removeMavenUpstreamRegistryAssociation.mockRejectedValue(mockError);
          createComponent();

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('remove-upstream', registryUpstreamAssociationId);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe('Failed to remove upstream. Try again.');
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
        });
      });
    });

    describe('when using GraphQL API', () => {
      describe('when succeeds', () => {
        beforeEach(() => {
          createComponent({
            provide: { deleteRegistryUpstreamMutation },
          });
          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('remove-upstream', registryUpstreamAssociationId);
        });

        it('calls the mutation with the right arguments', () => {
          expect(mockDeleteRegistryUpstream).toHaveBeenCalledWith({
            id: registryUpstreamAssociationId,
          });
        });

        it('does not call the REST API', () => {
          expect(removeMavenUpstreamRegistryAssociation).not.toHaveBeenCalled();
        });

        it('shows success toast and emits `update` event', async () => {
          await waitForPromises();

          expect(showToastSpy).toHaveBeenCalledWith('Removed upstream from virtual registry.');
          expect(wrapper.emitted('update')).toHaveLength(1);
          expect(captureException).not.toHaveBeenCalled();
        });
      });

      describe('when fails', () => {
        it('with mutation error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { deleteRegistryUpstreamMutation },
            deleteRegistryUpstreamHandler: jest
              .fn()
              .mockResolvedValue({ data: { upstreamDelete: { errors: ['error'] } } }),
          });

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('remove-upstream', registryUpstreamAssociationId);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe('Failed to remove upstream. Try again.');
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture('error'));
        });

        it('with server error shows alert and reports error to Sentry', async () => {
          createComponent({
            provide: { deleteRegistryUpstreamMutation },
            deleteRegistryUpstreamHandler: errorHandler,
          });

          const upstreamItems = findUpstreamItems();

          upstreamItems.at(0).vm.$emit('remove-upstream', registryUpstreamAssociationId);

          await waitForPromises();

          expect(findUpdateActionErrorAlert().text()).toBe('Failed to remove upstream. Try again.');
          expect(showToastSpy).not.toHaveBeenCalled();
          expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
        });
      });
    });
  });

  describe('clear registry cache action', () => {
    beforeEach(() => {
      deleteMavenRegistryCache.mockReset();
    });

    it('modal is shown with props', async () => {
      createComponent();

      await findClearRegistryCacheButton().vm.$emit('click');

      expect(findClearRegistryCacheModal().props('visible')).toBe(true);
      expect(findClearRegistryCacheModal().props('title')).toBe('Clear all caches?');
      expect(findClearRegistryCacheModal().text()).toBe(
        'This will delete all cached packages for exclusive upstream registries in this virtual registry. If any upstream is unavailable or misconfigured after clearing, jobs that rely on those packages might fail. Are you sure you want to continue?',
      );
    });

    it('hides modal on cancel', () => {
      createComponent();

      findClearRegistryCacheButton().vm.$emit('click');

      findClearRegistryCacheModal().vm.$emit('canceled');

      expect(findClearRegistryCacheModal().props('visible')).toBe(false);
    });

    describe('when modal is confirmed and REST API succeeds', () => {
      beforeEach(() => {
        deleteMavenRegistryCache.mockResolvedValue();
        createComponent();

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(deleteMavenRegistryCache).toHaveBeenCalledWith({
          id: getIdFromGraphQLId(registry.id),
        });
      });

      it('shows success toast', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Registry cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when modal is confirmed and REST API fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        deleteMavenRegistryCache.mockRejectedValue(mockError);
        createComponent();

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear registry cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
      });
    });

    describe('when modal is confirmed and GraphQL API succeeds', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            deleteRegistryCacheMutation,
          },
        });

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(mockDeleteRegistryCache).toHaveBeenCalledWith({
          id: registry.id,
        });
      });

      it('shows success toast', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Registry cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when modal is confirmed and GraphQL API fails', () => {
      it('with mutation error shows toast with default message & reports error to Sentry', async () => {
        createComponent({
          provide: {
            deleteRegistryCacheMutation,
          },
          deleteRegistryCacheHandler: jest
            .fn()
            .mockResolvedValue({ data: { registryCacheDelete: { errors: ['error'] } } }),
        });

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear registry cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(['error']));
      });

      it('with server error shows toast with default message & reports error to Sentry', async () => {
        createComponent({
          provide: {
            deleteRegistryCacheMutation,
          },
          deleteRegistryCacheHandler: errorHandler,
        });

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear registry cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
      });
    });
  });

  describe('clear upstream cache action', () => {
    beforeEach(() => {
      deleteMavenUpstreamCache.mockReset();
    });

    it('modal is shown with props', async () => {
      createComponent();

      const upstreamItems = findUpstreamItems();
      await upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);

      expect(findUpstreamClearCacheModal().props()).toStrictEqual({
        visible: true,
        upstreamName: 'name',
      });
    });

    it('hides modal on cancel', () => {
      createComponent();

      const upstreamItems = findUpstreamItems();
      upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);

      findUpstreamClearCacheModal().vm.$emit('canceled');

      expect(findUpstreamClearCacheModal().props('visible')).toBe(false);
    });

    describe('when modal is confirmed and REST API succeeds', () => {
      beforeEach(() => {
        deleteMavenUpstreamCache.mockResolvedValue();
        createComponent();
        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);
        findUpstreamClearCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(deleteMavenUpstreamCache).toHaveBeenCalledWith({
          id: getIdFromGraphQLId(registryUpstream.upstream.id),
        });
      });

      it('shows success toast when successful', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Upstream cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when REST API fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        deleteMavenUpstreamCache.mockRejectedValue(mockError);
        createComponent();

        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);
        findUpstreamClearCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear upstream cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(mockError));
      });
    });

    describe('when modal is confirmed and GraphQL API succeeds', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            deleteUpstreamCacheMutation,
          },
        });
        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);
        findUpstreamClearCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(mockDeleteUpstreamCache).toHaveBeenCalledWith({
          id: registryUpstream.upstream.id,
        });
      });

      it('shows success toast when successful', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Upstream cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when GraphQL API fails', () => {
      it('with mutation error shows toast with default message & reports error to Sentry', async () => {
        createComponent({
          provide: {
            deleteUpstreamCacheMutation,
          },
          deleteUpstreamCacheHandler: jest
            .fn()
            .mockResolvedValue({ data: { cacheDelete: { errors: ['error'] } } }),
        });

        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);
        findUpstreamClearCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear upstream cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(['error']));
      });

      it('with server error shows toast with default message & reports error to Sentry', async () => {
        createComponent({
          provide: {
            deleteUpstreamCacheMutation,
          },
          deleteUpstreamCacheHandler: errorHandler,
        });

        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clear-cache', registryUpstream.upstream);
        findUpstreamClearCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear upstream cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith(expectedCapture(mockGraphQLError));
      });
    });
  });

  describe('when maximum upstreams limit is reached', () => {
    const maxUpstreams = Array.from({ length: 20 }, (_, i) => ({
      id: `registry-upstream-${i}`,
      position: i + 1,
      upstream: [{ ...registryUpstream.upstream, id: `upstream-${i}`, name: `Upstream ${i}` }],
    }));

    beforeEach(() => {
      createComponent({
        props: {
          registryUpstreams: maxUpstreams,
        },
      });
    });

    it('renders upstreams count badge showing maximum reached', () => {
      expect(findUpstreamsCountBadge().text()).toBe('20 of 20');
    });

    it('shows max upstreams message instead of AddUpstream component', () => {
      expect(findMaxUpstreamsMessage().text()).toBe('Maximum number of upstreams reached.');
      expect(findAddUpstream().exists()).toBe(false);
    });
  });

  describe('upstreams count badge text', () => {
    it('shows correct count for single upstream', () => {
      createComponent({
        props: {
          registryUpstreams: [registryUpstream],
        },
      });

      expect(findUpstreamsCountBadge().text()).toBe('1 of 20');
    });

    it('shows correct count for no upstreams', () => {
      createComponent({
        props: {
          registryUpstreams: [],
        },
      });

      expect(findUpstreamsCountBadge().text()).toBe('0 of 20');
    });
  });
});
