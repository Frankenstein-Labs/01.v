import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PipelineSubscriptionsApp from 'ee/ci/pipeline_subscriptions/pipeline_subscriptions_app.vue';
import PipelineSubscriptionsTable from 'ee/ci/pipeline_subscriptions/components/pipeline_subscriptions_table.vue';
import DeleteSubscriptionConfirmationModal from 'ee/ci/pipeline_subscriptions/components/delete_subscription_confirmation_modal.vue';
import getUpstreamSubscriptions from 'ee/ci/pipeline_subscriptions/graphql/queries/get_upstream_subscriptions.query.graphql';
import getDownstreamSubscriptions from 'ee/ci/pipeline_subscriptions/graphql/queries/get_downstream_subscriptions.query.graphql';
import deletePipelineSubscription from 'ee/ci/pipeline_subscriptions/graphql/mutations/delete_pipeline_subscription.mutation.graphql';

import {
  deleteMutationResponse,
  mockUpstreamSubscriptions,
  mockDownstreamSubscriptions,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Pipeline subscriptions app', () => {
  let wrapper;

  const upstreamHanlder = jest.fn().mockResolvedValue(mockUpstreamSubscriptions);
  const downstreamHandler = jest.fn().mockResolvedValue(mockDownstreamSubscriptions);
  const deleteMutationHandler = jest.fn().mockResolvedValue(deleteMutationResponse);
  const failedHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const findLoadingIcons = () => wrapper.findAllComponents(GlLoadingIcon);
  const findTables = () => wrapper.findAllComponents(PipelineSubscriptionsTable);
  const findModal = () => wrapper.findComponent(DeleteSubscriptionConfirmationModal);

  const defaultHandlers = [
    [getUpstreamSubscriptions, upstreamHanlder],
    [getDownstreamSubscriptions, downstreamHandler],
  ];

  const mockId = mockUpstreamSubscriptions.data.project.ciSubscriptionsProjects.nodes[0].id;

  const defaultProvideOptions = {
    projectPath: '/namespace/my-project',
  };

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = (handlers = defaultHandlers) => {
    wrapper = shallowMountExtended(PipelineSubscriptionsApp, {
      provide: {
        ...defaultProvideOptions,
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  describe('loading state', () => {
    it('shows loading icons', () => {
      createComponent();

      expect(findLoadingIcons()).toHaveLength(2);
    });
  });

  describe('defaults', () => {
    it('does not show loading icons', async () => {
      createComponent();

      await waitForPromises();

      expect(findLoadingIcons()).toHaveLength(0);
    });

    it('shows upstream/downstream pipeline subscription tables', async () => {
      createComponent();

      await waitForPromises();

      expect(findTables()).toHaveLength(2);
    });

    it('formats subscription data for table', async () => {
      createComponent();

      await waitForPromises();

      const { id, upstreamProject } =
        mockUpstreamSubscriptions.data.project.ciSubscriptionsProjects.nodes[0];

      const expectedFormat = [
        {
          id,
          project: upstreamProject,
        },
      ];

      expect(findTables().at(0).props('subscriptions')).toEqual(expectedFormat);
    });

    it('deletes pipeline subscription and refetches upstream subscriptions', async () => {
      createComponent([
        [getUpstreamSubscriptions, upstreamHanlder],
        [getDownstreamSubscriptions, downstreamHandler],
        [deletePipelineSubscription, deleteMutationHandler],
      ]);

      await waitForPromises();

      expect(upstreamHanlder).toHaveBeenCalledTimes(1);

      findTables().at(0).vm.$emit('show-modal', mockId);

      findModal().vm.$emit('delete-confirmed');

      await waitForPromises();

      expect(deleteMutationHandler).toHaveBeenCalledWith({
        id: mockId,
      });
      expect(upstreamHanlder).toHaveBeenCalledTimes(2);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Subscription successfully deleted.',
        variant: 'success',
      });
    });

    it('refetches subscriptions after adding a new subscription', async () => {
      createComponent();

      await waitForPromises();

      expect(upstreamHanlder).toHaveBeenCalledTimes(1);

      findTables().at(0).vm.$emit('refetch-subscriptions');

      expect(upstreamHanlder).toHaveBeenCalledTimes(2);
    });
  });

  describe('failures', () => {
    it('shows error alert when upstream subscriptions query fetch fails', async () => {
      createComponent([
        [getUpstreamSubscriptions, failedHandler],
        [getDownstreamSubscriptions, downstreamHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching upstream pipeline subscriptions.',
      });
    });

    it('shows error alert when downstream subscriptions query fetch fails', async () => {
      createComponent([
        [getUpstreamSubscriptions, upstreamHanlder],
        [getDownstreamSubscriptions, failedHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching downstream pipeline subscriptions.',
      });
    });

    it('shows error alert when delete pipeline subscription mutation fails', async () => {
      createComponent([
        [getUpstreamSubscriptions, upstreamHanlder],
        [getDownstreamSubscriptions, downstreamHandler],
        [deletePipelineSubscription, failedHandler],
      ]);

      await waitForPromises();

      findTables().at(0).vm.$emit('show-modal', mockId);

      findModal().vm.$emit('delete-confirmed');

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while deleting this pipeline subscription.',
      });
    });
  });
});
