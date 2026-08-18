import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { updateMavenUpstream } from 'ee/api/virtual_registries_api';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import UpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/form.vue';
import UpstreamEdit from 'ee/packages_and_registries/virtual_registries/pages/common/upstream/edit.vue';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/delete_modal.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import updateUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/update_container_upstream.mutation.graphql';
import getUpstreamQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstream.query.graphql';
import { mockContainerUpstreamResponse } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

jest.mock('ee/api/virtual_registries_api', () => ({
  updateMavenUpstream: jest.fn(),
}));

Vue.use(VueApollo);

describe('UpstreamEdit', () => {
  let wrapper;

  const defaultProvide = {
    initialUpstream: {
      id: 1,
      name: 'Upstream',
      url: 'http://local.test/maven/',
      description: null,
      username: null,
      cacheValidityHours: 24,
    },
    upstreamsPath: '/groups/package-group/-/virtual_registries/maven?tab=upstreams',
    upstreamPath: '/groups/package-group/-/virtual_registries/maven/upstreams/3',
    glAbilities: {
      destroyVirtualRegistry: true,
    },
    ids: {
      baseUpstream: 'VirtualRegistries::Container::Upstream',
    },
  };

  const findModal = () => wrapper.findComponent(DeleteUpstreamWithModal);
  const findAlert = () => wrapper.findComponent(ErrorsAlert);
  const findDeleteUpstreamBtn = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(UpstreamForm);

  const upstreamHandler = jest
    .fn()
    .mockResolvedValue({ data: { upstream: mockContainerUpstreamResponse } });
  const updateUpstreamHandler = jest.fn().mockResolvedValue({
    data: {
      updateUpstream: {
        upstream: {
          id: 'gid://gitlab/VirtualRegistries::Container::Upstream/1',
          name: 'New Upstream',
          url: 'http://local.test/container/',
          description: 'description',
          cacheValidityHours: 24,
        },
        errors: [],
      },
    },
  });
  const mockError = new Error('API error');

  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({
    provide,
    propsData = {},
    handlers = [
      [getUpstreamQuery, upstreamHandler],
      [updateUpstreamMutation, updateUpstreamHandler],
    ],
  } = {}) => {
    wrapper = shallowMountExtended(UpstreamEdit, {
      apolloProvider: createMockApollo(handlers),
      propsData,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $router: mockRouter,
      },
    });
  };

  beforeEach(() => {
    updateMavenUpstream.mockReset();
  });

  describe('render', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays registry form', () => {
      expect(findForm().props('upstream')).toStrictEqual({
        id: 1,
        name: 'Upstream',
        url: 'http://local.test/maven/',
        description: null,
        username: null,
        cacheValidityHours: 24,
      });
    });

    it('sets correct props on DeleteUpstreamWithModal component', () => {
      expect(findModal().props()).toStrictEqual({
        upstreamId: 1,
        upstreamName: 'Upstream',
        visible: false,
      });
    });

    it('shows delete button', () => {
      expect(findDeleteUpstreamBtn().exists()).toBe(true);
    });

    describe('clicking on delete button', () => {
      it('sets modal to visible', async () => {
        await findDeleteUpstreamBtn().vm.$emit('click');

        expect(findModal().props('visible')).toBe(true);
      });
    });

    describe('without permission', () => {
      it('does not show delete button', () => {
        createComponent({
          provide: {
            glAbilities: {
              destroyVirtualRegistry: false,
            },
          },
        });

        expect(findDeleteUpstreamBtn().exists()).toBe(false);
      });
    });
  });

  describe('with GraphQL query', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          id: '1',
        },
        provide: {
          initialUpstream: {},
          getUpstreamQuery,
          updateUpstreamMutation,
        },
      });
    });

    it('displays skeleton loader while loading', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
      expect(upstreamHandler).toHaveBeenCalledTimes(1);
      expect(upstreamHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Container::Upstream/1',
      });
      expect(findForm().exists()).toBe(false);
      expect(findModal().exists()).toBe(false);
    });

    it('displays registry form', async () => {
      await waitForPromises();

      expect(findForm().props('upstream')).toStrictEqual(mockContainerUpstreamResponse);
    });

    it('sets correct props on DeleteUpstreamWithModal component', async () => {
      await waitForPromises();

      expect(findModal().props()).toStrictEqual({
        upstreamId: 1,
        upstreamName: 'Container',
        visible: false,
      });
    });

    it('shows empty state when upstream is not found', async () => {
      createComponent({
        handlers: [[getUpstreamQuery, jest.fn().mockResolvedValue({ data: { upstream: null } })]],
        provide: {
          initialUpstream: {},
          getUpstreamQuery,
        },
        propsData: {
          id: 1,
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    });
  });

  describe('updating registry', () => {
    const formData = {
      name: 'New Upstream',
      url: 'http://local.test/maven/',
      description: 'description',
      username: null,
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
    };

    describe('with REST API (Maven)', () => {
      it('calls updateUpstream API with correct ID', async () => {
        createComponent();

        await findForm().vm.$emit('submit', formData);

        const expectedData = {
          name: 'New Upstream',
          url: 'http://local.test/maven/',
          description: 'description',
          username: null,
          cache_validity_hours: 24,
          metadata_cache_validity_hours: 48,
        };
        expect(updateMavenUpstream).toHaveBeenCalledWith({ data: expectedData, id: 1 });
        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          '/groups/package-group/-/virtual_registries/maven/upstreams/3',
          [{ message: 'Maven upstream has been updated.' }],
        );
      });
    });

    describe('with GraphQL mutation (Container)', () => {
      const containerFormData = {
        name: 'New Upstream',
        url: 'http://local.test/container/',
        description: 'description',
        username: null,
        cacheValidityHours: 24,
      };

      it('calls GraphQL mutation with correct variables', async () => {
        createComponent({
          handlers: [
            [getUpstreamQuery, upstreamHandler],
            [updateUpstreamMutation, updateUpstreamHandler],
          ],
          provide: {
            updateUpstreamMutation,
          },
        });

        await findForm().vm.$emit('submit', containerFormData);

        expect(updateUpstreamHandler).toHaveBeenCalledWith({
          id: mockContainerUpstreamResponse.id,
          name: 'New Upstream',
          url: 'http://local.test/container/',
          description: 'description',
          username: null,
          cacheValidityHours: 24,
        });
      });

      it('shows success message and navigates on successful GraphQL mutation', async () => {
        createComponent({
          handlers: [
            [getUpstreamQuery, upstreamHandler],
            [updateUpstreamMutation, updateUpstreamHandler],
          ],
          provide: {
            updateUpstreamMutation,
            routes: {
              showUpstreamRouteName: 'CONTAINER_UPSTREAMS_SHOW',
            },
          },
        });

        await findForm().vm.$emit('submit', containerFormData);
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: 'CONTAINER_UPSTREAMS_SHOW',
          params: { id: 1 },
        });
      });

      it('shows error message when GraphQL mutation returns errors', async () => {
        const mockMutationHandler = jest.fn().mockResolvedValue({
          data: {
            updateUpstream: {
              upstream: null,
              errors: ['Name is too long'],
            },
          },
        });

        createComponent({
          handlers: [
            [getUpstreamQuery, jest.fn().mockResolvedValue({ data: { upstream: null } })],
            [updateUpstreamMutation, mockMutationHandler],
          ],
          provide: {
            updateUpstreamMutation,
          },
        });

        await findForm().vm.$emit('submit', containerFormData);
        await waitForPromises();

        expect(findAlert().props('errors')).toEqual(['Name is too long']);
      });

      it('clears errors when alert is dismissed', async () => {
        const mockMutationHandler = jest.fn().mockRejectedValue(new Error('server error'));

        createComponent({
          handlers: [
            [getUpstreamQuery, upstreamHandler],
            [updateUpstreamMutation, mockMutationHandler],
          ],
          provide: {
            updateUpstreamMutation,
          },
        });

        await findForm().vm.$emit('submit', containerFormData);
        await waitForPromises();

        expect(findAlert().props('errors')).toEqual(['server error']);

        await findAlert().vm.$emit('dismiss');

        expect(findAlert().props('errors')).toEqual([]);
      });
    });

    it('parses error message on REST API failure', async () => {
      updateMavenUpstream.mockRejectedValue({
        response: {
          status: 400,
          data: { message: { group: ['already has an upstream with the same credentials'] } },
        },
      });

      createComponent();

      expect(findAlert().props('errors')).toEqual([]);

      findForm().vm.$emit('submit', formData);

      await waitForPromises();

      expect(findAlert().props('errors')).toEqual([
        'group already has an upstream with the same credentials',
      ]);
      expect(captureException).not.toHaveBeenCalled();
    });

    it('shows error alert on REST API failure', async () => {
      updateMavenUpstream.mockRejectedValue(mockError);

      createComponent();

      expect(findAlert().props('errors')).toEqual([]);

      findForm().vm.$emit('submit', formData);

      await waitForPromises();

      expect(findAlert().props('errors')).toEqual(['API error']);
      expect(captureException).toHaveBeenCalledWith({
        component: 'UpstreamEdit',
        error: mockError,
      });
    });
  });

  describe('deleting registry', () => {
    beforeEach(() => {
      createComponent();
      findDeleteUpstreamBtn().vm.$emit('click');
    });

    it('calls visitUrlWithAlerts when DeleteUpstreamWithModal emits success', () => {
      findModal().vm.$emit('success');

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        '/groups/package-group/-/virtual_registries/maven?tab=upstreams',
        [{ message: 'Maven upstream has been deleted.' }],
      );
    });

    it('shows error alert when DeleteUpstreamWithModal emits error', async () => {
      expect(findAlert().props('errors')).toEqual([]);

      await findModal().vm.$emit('error', mockError);

      expect(findAlert().props('errors')).toEqual(['API error']);
      expect(captureException).toHaveBeenCalledWith({
        component: 'UpstreamEdit',
        error: mockError,
      });
    });
  });
});
