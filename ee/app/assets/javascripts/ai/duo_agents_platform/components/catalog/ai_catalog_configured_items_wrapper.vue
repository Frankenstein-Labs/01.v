<script>
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
} from 'ee/ai/catalog/constants';
import { initialPaginationParams, reactivePaginationMethods } from 'ee/ai/catalog/pagination_utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import { getRegistryItem } from 'ee/ai/catalog/item_type_registry';

export default {
  name: 'AiCatalogConfiguredItemsWrapper',
  components: {
    AiCatalogList,
  },
  mixins: [glFeatureFlagsMixin(), GlToastMixin],
  inject: {
    isProjectNamespace: {},
    groupId: {
      default: null,
    },
    projectId: {
      default: null,
    },
  },
  props: {
    disableConfirmTitle: {
      type: String,
      required: false,
      default: null,
    },
    disableConfirmMessage: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateTitle: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateDescription: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateButtonHref: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateButtonText: {
      type: String,
      required: false,
      default: null,
    },
    itemTypes: {
      type: Array,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
      validator(item) {
        return item.showRoute && item.visibilityTooltip;
      },
    },
    disabledItemTypeMessages: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['empty-state-click', 'error'],
  data() {
    return {
      configuredItems: [],
      pageInfo: {},
      paginationVariables: initialPaginationParams(),
    };
  },
  apollo: {
    configuredItems: {
      query: aiCatalogConfiguredItemsQuery,
      // fetchPolicy needed to refresh items after deletion from the show page
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          itemTypes: this.itemTypes,
          includeFoundationalConsumers: true,
          ...this.namespaceVariables,
          ...this.paginationVariables,
        };
      },
      // `item` is null when the viewer cannot read the referenced catalog item.
      update: (data) => data.aiCatalogConfiguredItems.nodes.filter((node) => node.item),
      result({ data }) {
        if (data?.aiCatalogConfiguredItems) {
          this.pageInfo = data.aiCatalogConfiguredItems.pageInfo;
        }
      },
      error(error) {
        this.$emit('error', {
          title: s__('AICatalog|Failed to load items.'),
          errors: [error.message],
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.configuredItems.loading;
    },
    namespaceVariables() {
      if (this.isProjectNamespace) {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
        };
      }
      return {
        groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
      };
    },
    namespaceTypeLabel() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_PROJECT]
        : AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_GROUP];
    },
    items() {
      return this.configuredItems.map((configuredItem) => {
        const { item, ...itemConsumerData } = configuredItem;
        const isUpdateAvailable =
          item.latestVersion != null &&
          item.latestVersion.humanVersionName !==
            itemConsumerData.pinnedItemVersion?.humanVersionName;

        return {
          ...item,
          itemConsumer: itemConsumerData,
          isUpdateAvailable,
        };
      });
    },
  },
  methods: {
    async disableItem(item) {
      const { id } = item.itemConsumer;
      const { itemType } = item;
      const { disable } = getRegistryItem(itemType);

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogConfiguredItemsQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.$emit('error', {
            title: disable.error,
            errors: data.aiCatalogItemConsumerDelete.errors,
          });
          return;
        }

        this.$toast.show(
          sprintf(disable.success, {
            namespaceType: this.namespaceTypeLabel,
          }),
        );
      } catch (error) {
        this.$emit('error', {
          title: disable.error,
          errors: [error.message],
        });
        Sentry.captureException(error);
      }
    },
    ...reactivePaginationMethods,
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <ai-catalog-list
    :is-loading="isLoading"
    :items="items"
    :item-type-config="itemTypeConfig"
    :disable-confirm-title="disableConfirmTitle"
    :disable-confirm-message="disableConfirmMessage"
    :disabled-item-type-messages="disabledItemTypeMessages"
    :disable-fn="disableItem"
    :page-info="pageInfo"
    :empty-state-title="emptyStateTitle"
    :empty-state-description="emptyStateDescription"
    :empty-state-button-href="emptyStateButtonHref"
    :empty-state-button-text="emptyStateButtonText"
    @empty-state-click="$emit('empty-state-click')"
    @next-page="handleNextPage"
    @prev-page="handlePrevPage"
  />
</template>
