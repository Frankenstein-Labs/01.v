<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import GetUpstreamSubscriptions from './graphql/queries/get_upstream_subscriptions.query.graphql';
import GetDownstreamSubscriptions from './graphql/queries/get_downstream_subscriptions.query.graphql';
import DeletePipelineSubscription from './graphql/mutations/delete_pipeline_subscription.mutation.graphql';
import DeleteSubscriptionConfirmationModal from './components/delete_subscription_confirmation_modal.vue';
import PipelineSubscriptionsTable from './components/pipeline_subscriptions_table.vue';

export default {
  name: 'PipelineSubscriptionsApp',
  i18n: {
    upstreamFetchError: s__(
      'PipelineSubscriptions|An error occurred while fetching upstream pipeline subscriptions.',
    ),
    downstreamFetchError: s__(
      'PipelineSubscriptions|An error occurred while fetching downstream pipeline subscriptions.',
    ),
    upstreamTitle: s__('PipelineSubscriptions|Subscriptions'),
    downstreamTitle: s__('PipelineSubscriptions|Subscribed to this project'),
    upstreamEmptyText: s__(
      'PipelineSubscriptions|This project is not subscribed to any project pipelines.',
    ),
    downstreamEmptyText: s__(
      'PipelineSubscriptions|No project subscribes to the pipelines in this project.',
    ),
    deleteError: s__(
      'PipelineSubscriptions|An error occurred while deleting this pipeline subscription.',
    ),
    deleteSuccess: s__('PipelineSubscriptions|Subscription successfully deleted.'),
  },
  components: {
    DeleteSubscriptionConfirmationModal,
    GlLoadingIcon,
    PipelineSubscriptionsTable,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  apollo: {
    upstreamSubscriptions: {
      query: GetUpstreamSubscriptions,
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update({ project: { ciSubscriptionsProjects } }) {
        return {
          count: ciSubscriptionsProjects.count,
          nodes: ciSubscriptionsProjects.nodes.map((subscription) => {
            return {
              id: subscription.id,
              project: subscription.upstreamProject,
            };
          }),
        };
      },
      error() {
        createAlert({ message: this.$options.i18n.upstreamFetchError });
      },
    },
    downstreamSubscriptions: {
      query: GetDownstreamSubscriptions,
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update({ project: { ciSubscribedProjects } }) {
        return {
          count: ciSubscribedProjects.count,
          nodes: ciSubscribedProjects.nodes.map((subscription) => {
            return {
              id: subscription.id,
              project: subscription.downstreamProject,
            };
          }),
        };
      },
      error() {
        createAlert({ message: this.$options.i18n.downstreamFetchError });
      },
    },
  },
  data() {
    return {
      upstreamSubscriptions: {
        count: 0,
        nodes: [],
      },
      downstreamSubscriptions: {
        count: 0,
        nodes: [],
      },
      subscriptionToDelete: null,
      isModalVisible: false,
    };
  },
  computed: {
    upstreamSubscriptionsLoading() {
      return this.$apollo.queries.upstreamSubscriptions.loading;
    },
    downstreamSubscriptionsLoading() {
      return this.$apollo.queries.downstreamSubscriptions.loading;
    },
  },
  methods: {
    async deleteSubscription() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: DeletePipelineSubscription,
          variables: { id: this.subscriptionToDelete },
        });

        if (data.projectSubscriptionDelete.errors.length > 0) {
          createAlert({ message: data.projectSubscriptionDelete.errors[0] });
          this.subscriptionToDelete = null;
        } else {
          createAlert({ message: this.$options.i18n.deleteSuccess, variant: 'success' });
          this.refetchUpstreamSubscriptions();
        }
      } catch {
        createAlert({ message: this.$options.i18n.deleteError });
        this.subscriptionToDelete = null;
      }
    },
    showModal(id) {
      this.isModalVisible = true;
      this.subscriptionToDelete = id;
    },
    hideModal() {
      this.isModalVisible = false;
      this.subscriptionToDelete = null;
    },
    refetchUpstreamSubscriptions() {
      this.$apollo.queries.upstreamSubscriptions.refetch();
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="upstreamSubscriptionsLoading" />
    <pipeline-subscriptions-table
      v-else
      :count="upstreamSubscriptions.count"
      :subscriptions="upstreamSubscriptions.nodes"
      :title="$options.i18n.upstreamTitle"
      :empty-text="$options.i18n.upstreamEmptyText"
      show-actions
      data-testid="upstream-project-subscriptions"
      @show-modal="showModal"
      @refetch-subscriptions="refetchUpstreamSubscriptions"
    />

    <gl-loading-icon v-if="downstreamSubscriptionsLoading" />
    <pipeline-subscriptions-table
      v-else
      :count="downstreamSubscriptions.count"
      :subscriptions="downstreamSubscriptions.nodes"
      :title="$options.i18n.downstreamTitle"
      :empty-text="$options.i18n.downstreamEmptyText"
      data-testid="downstream-project-subscriptions"
    />

    <delete-subscription-confirmation-modal
      :is-modal-visible="isModalVisible"
      @delete-confirmed="deleteSubscription"
      @hide="hideModal"
    />
  </div>
</template>
