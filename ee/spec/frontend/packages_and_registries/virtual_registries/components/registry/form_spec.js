import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import RegistryForm from 'ee/packages_and_registries/virtual_registries/components/registry/form.vue';
import createRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_container_registry.mutation.graphql';
import updateRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/update_container_registry.mutation.graphql';
import getRegistryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_registry.query.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');
jest.mock('~/alert');

Vue.use(VueApollo);

describe('Virtual registry form component', () => {
  let wrapper;

  const createMutationHandler = jest.fn().mockResolvedValue({
    data: {
      createRegistry: {
        errors: [],
        registry: {
          id: 1,
          name: 'Registry name',
          description: 'Registry description',
        },
      },
    },
  });
  const updateMutationHandler = jest.fn().mockResolvedValue({
    data: {
      updateRegistry: {
        errors: [],
        registry: {
          id: 1,
          name: 'Registry name',
          description: 'Registry description',
        },
      },
    },
  });
  const routerPushMock = jest.fn();

  const findFormFields = () => wrapper.findComponentByTestId('registry-form');
  const findErrorMessage = () => wrapper.findComponent(ErrorsAlert);

  function factory({
    createHandler = createMutationHandler,
    updateHandler = updateMutationHandler,
    propsData = {},
  } = {}) {
    const apolloProvider = createMockApollo([
      [createRegistryMutation, createHandler],
      [updateRegistryMutation, updateHandler],
    ]);

    wrapper = mountExtended(RegistryForm, {
      apolloProvider,
      provide: {
        fullPath: 'gitlab-org',
        createRegistryMutation,
        updateRegistryMutation,
        getRegistryQuery,
        routes: { showRegistryRouteName: 'show' },
      },
      propsData: {
        ...propsData,
      },
      stubs: {
        RouterLink: true,
      },
      mocks: {
        $router: {
          push: routerPushMock,
        },
      },
    });
  }

  it('renders form fields with name and description in fields prop', () => {
    factory();

    expect(findFormFields().props('fields')).toEqual(
      expect.objectContaining({
        name: expect.any(Object),
        description: expect.any(Object),
      }),
    );
  });

  describe('when create mutation is submitted', () => {
    it('sends registry data on submit', async () => {
      factory();

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(createMutationHandler).toHaveBeenCalledWith({
        input: {
          description: 'Registry description',
          name: 'Registry name',
          groupPath: 'gitlab-org',
        },
      });
    });

    it('pushes new route', async () => {
      factory();

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(routerPushMock).toHaveBeenCalledWith({
        params: {
          id: 1,
        },
        name: 'show',
      });
    });

    it('shows success alert message', async () => {
      factory();

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Registry Registry name was successfully created.',
        variant: 'success',
      });
    });

    describe('when mutation returns error', () => {
      it('renders error message', async () => {
        const errorHandler = jest.fn().mockResolvedValue({
          data: {
            createRegistry: {
              errors: ['Error!', 'Another error'],
              registry: null,
            },
          },
        });

        factory({ createHandler: errorHandler });

        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessage().props('errors')).toEqual(['Error!', 'Another error']);
      });
    });

    describe('when server returns error', () => {
      beforeEach(() => {
        const errorHandler = jest.fn().mockRejectedValue({
          data: {
            createRegistry: {
              errors: [],
              registry: null,
            },
          },
        });

        factory({ createHandler: errorHandler });
      });

      it('renders error message', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessage().props('errors')).toEqual([
          'Something went wrong. Please try again.',
        ]);
      });

      it('captures exception', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(captureException).toHaveBeenCalledWith({
          component: 'RegistryForm',
          error: expect.anything(),
        });
      });
    });
  });

  describe('when update mutation is submitted', () => {
    const registryId = '1';
    const initialRegistry = { name: 'Test name', description: 'Test description' };

    it('sends registry data on submit', async () => {
      factory({ propsData: { registryId, initialRegistry } });

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(updateMutationHandler).toHaveBeenCalledWith({
        input: {
          description: 'Registry description',
          name: 'Registry name',
          id: registryId,
        },
      });
    });

    it('pushes new route', async () => {
      factory({ propsData: { registryId, initialRegistry } });

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(routerPushMock).toHaveBeenCalledWith({
        params: {
          id: 1,
        },
        name: expect.any(String),
      });
    });

    describe('when mutation returns error', () => {
      it('renders error message', async () => {
        const errorHandler = jest.fn().mockResolvedValue({
          data: {
            updateRegistry: {
              errors: ['Error!', 'Another error'],
              registry: null,
            },
          },
        });

        factory({ updateHandler: errorHandler, propsData: { registryId, initialRegistry } });

        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessage().props('errors')).toEqual(['Error!', 'Another error']);
      });
    });

    describe('when server returns error', () => {
      beforeEach(() => {
        const errorHandler = jest.fn().mockRejectedValue({
          data: {
            updateRegistry: {
              errors: [],
              registry: null,
            },
          },
        });

        factory({ updateHandler: errorHandler, propsData: { registryId, initialRegistry } });
      });

      it('renders error message', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessage().props('errors')).toEqual([
          'Something went wrong. Please try again.',
        ]);
      });

      it('captures exception', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(captureException).toHaveBeenCalledWith({
          component: 'RegistryForm',
          error: expect.anything(),
        });
      });
    });
  });
});
