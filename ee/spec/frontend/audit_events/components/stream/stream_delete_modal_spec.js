import { GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import deleteGroupStreamingDestinationsQuery from 'ee/audit_events/graphql/mutations/delete_group_streaming_destination.mutation.graphql';
import deleteInstanceStreamingDestinationsQuery from 'ee/audit_events/graphql/mutations/delete_instance_streaming_destination.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { groupPath, instanceGroupPath } from '../../mock_data';
import {
  mockHttpTypeDestination,
  streamingDestinationDeleteMutationPopulator,
} from '../../mock_data/consolidated_api';

Vue.use(VueApollo);

describe('StreamDeleteModal', () => {
  let wrapper;

  const deleteStreamingSuccess = jest
    .fn()
    .mockResolvedValue(streamingDestinationDeleteMutationPopulator());
  const deleteStreamingError = jest
    .fn()
    .mockResolvedValue(streamingDestinationDeleteMutationPopulator(['Random Error message']));
  const deleteStreamingNetworkError = jest
    .fn()
    .mockRejectedValue(streamingDestinationDeleteMutationPopulator(['Network error']));

  const deleteInstanceStreamingSuccess = jest.fn().mockResolvedValue({
    data: {
      instanceAuditEventStreamingDestinationsDelete: {
        errors: [],
      },
    },
  });
  const deleteInstanceStreamingError = jest.fn().mockResolvedValue({
    data: {
      instanceAuditEventStreamingDestinationsDelete: {
        errors: ['Random Error message'],
      },
    },
  });
  const deleteInstanceStreamingNetworkError = jest.fn().mockRejectedValue({
    data: {
      instanceAuditEventStreamingDestinationsDelete: {
        errors: ['Network error'],
      },
    },
  });

  let groupPathProvide = groupPath;
  let itemProvide = mockHttpTypeDestination[0];
  let deleteExternalDestinationProvide = deleteGroupStreamingDestinationsQuery;

  const findModal = () => wrapper.findComponent(GlModal);
  const clickDeleteFramework = () => findModal().vm.$emit('primary');

  const createComponent = (resolverMock) => {
    const mockApollo = createMockApollo([[deleteExternalDestinationProvide, resolverMock]]);

    wrapper = shallowMount(StreamDeleteModal, {
      apolloProvider: mockApollo,
      propsData: {
        item: itemProvide,
      },
      provide: {
        groupPath: groupPathProvide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('component layout', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets the modal id', () => {
      expect(findModal().props('modalId')).toBe('delete-destination-modal');
    });

    it('sets the modal primary button attributes', () => {
      const actionPrimary = findModal().props('actionPrimary');

      expect(actionPrimary.text).toBe('Delete destination');
      expect(actionPrimary.attributes.variant).toBe('danger');
    });

    it('sets the modal cancel button attributes', () => {
      expect(findModal().props('actionCancel').text).toBe('Cancel');
    });
  });

  describe('Group HTTP clickDeleteDestination', () => {
    beforeEach(() => {
      deleteExternalDestinationProvide = deleteGroupStreamingDestinationsQuery;
      [itemProvide] = mockHttpTypeDestination;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent(deleteStreamingSuccess);
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteStreamingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteStreamingSuccess).toHaveBeenCalledWith({
        id: mockHttpTypeDestination[0].id,
        isInstance: false,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteStreamingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteStreamingNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteStreamingError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('Instance clickDeleteDestination', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
      deleteExternalDestinationProvide = deleteInstanceStreamingDestinationsQuery;
      [itemProvide] = mockHttpTypeDestination;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent(deleteInstanceStreamingSuccess);
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteInstanceStreamingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteInstanceStreamingSuccess).toHaveBeenCalledWith({
        id: mockHttpTypeDestination[0].id,
        isInstance: true,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteInstanceStreamingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteInstanceStreamingNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteInstanceStreamingError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });
});
