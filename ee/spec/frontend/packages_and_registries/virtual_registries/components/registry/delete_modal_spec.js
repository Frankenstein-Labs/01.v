import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal } from '@gitlab/ui';
import containerRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_container_virtual_registries.query.graphql.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DeleteModal from 'ee/packages_and_registries/virtual_registries/components/registry/delete_modal.vue';
import deleteRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/delete_container_registry.mutation.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Registry delete modal', () => {
  let wrapper;

  let routerPush;
  const findModal = () => wrapper.findComponent(GlModal);
  const defaultDeleteHandler = jest.fn().mockResolvedValue({ data: { delete: { errors: [] } } });

  function createComponent({
    registry = containerRegistriesPayload.data.group.registries.nodes[0],
    deleteHandler = defaultDeleteHandler,
  } = {}) {
    const handlers = [[deleteRegistryMutation, deleteHandler]];

    routerPush = jest.fn();

    wrapper = shallowMountExtended(DeleteModal, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        registry,
      },
      provide: {
        fullPath: 'gitlab-org',
        deleteRegistryMutation,
        routes: { listRegistryRouteName: 'index' },
      },
      mocks: {
        $router: {
          push: routerPush,
        },
      },
    });
  }

  it('calls mutation on modals primary action', async () => {
    createComponent();

    findModal().vm.$emit('primary');

    await waitForPromises();

    expect(defaultDeleteHandler).toHaveBeenCalledWith({
      id: containerRegistriesPayload.data.group.registries.nodes[0].id,
    });
  });

  it('emits hidden event on modals hidden event', () => {
    createComponent();

    findModal().vm.$emit('hidden');

    expect(wrapper.emitted('hidden')).toHaveLength(1);
  });

  describe('when successful', () => {
    beforeEach(async () => {
      createComponent();

      findModal().vm.$emit('primary');

      await waitForPromises();
    });

    it('shows success alert when mutation errors', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Virtual registry deleted successfully.',
        variant: 'success',
      });
    });

    it('returns router to index page', () => {
      expect(routerPush).toHaveBeenCalledWith({
        name: 'index',
      });
    });
  });

  describe('with error', () => {
    beforeEach(async () => {
      createComponent({ deleteHandler: jest.fn().mockRejectedValue(new Error()) });

      findModal().vm.$emit('primary');

      await waitForPromises();
    });

    it('shows alert when mutation errors', () => {
      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: expect.any(Error),
        message: 'Failed to delete registry. Please try again.',
      });
    });

    it('emits hidden event', () => {
      expect(wrapper.emitted('hidden')).toHaveLength(1);
    });
  });
});
