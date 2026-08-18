<script>
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogListWrapper from '../components/ai_catalog_list_wrapper.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  DEFAULT_SORT,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  AI_CATALOG_APOLLO_LIST_QUERY,
  AI_CATALOG_APOLLO_CUSTOM_AND_FOUNDATIONAL_LIST_QUERY,
} from '../constants';
import { getRegistryItem, itemTypeValidator } from '../item_type_registry';
import { initialPaginationParams, reactivePaginationMethods } from '../pagination_utils';
import { isSortDirectionless, sortingComputeds } from '../sorting_utils';
import { normalizeCustomOrFoundationalItem } from '../utils';

export default {
  name: 'AiCatalogItemsIndex',
  components: {
    AiCatalogListHeader,
    AiCatalogListWrapper,
    ErrorsAlert,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  props: {
    itemType: {
      type: String,
      required: true,
      validator: itemTypeValidator,
    },
  },
  data() {
    return {
      aiCatalogItems: [],
      pageInfo: {},
      paginationVariables: initialPaginationParams(),
      searchTerm: this.$route.query.search || '',
      sort: this.$route.query.sort || DEFAULT_SORT,
      errors: [],
    };
  },
  apollo: {
    aiCatalogItems: {
      query() {
        return this.listQuery;
      },
      variables() {
        return {
          itemTypes: this.resolvedItemTypes,
          ...this.paginationVariables,
          search: this.searchTerm,
          sort: this.sortGraphQLValue,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        const nodes = data?.[this.responseKey]?.nodes || [];
        return nodes.map(normalizeCustomOrFoundationalItem);
      },
      result({ data }) {
        this.pageInfo = data?.[this.responseKey]?.pageInfo || {};
      },
      error(error) {
        this.errors = [this.itemRegistry.index.errorMessage];
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    includeFoundationalItems() {
      return (
        this.itemType === AI_CATALOG_TYPE_AGENT &&
        Boolean(this.glFeatures.aiCatalogSyntheticFoundationalItems)
      );
    },
    listQuery() {
      return this.includeFoundationalItems
        ? AI_CATALOG_APOLLO_CUSTOM_AND_FOUNDATIONAL_LIST_QUERY
        : AI_CATALOG_APOLLO_LIST_QUERY;
    },
    responseKey() {
      return this.includeFoundationalItems
        ? 'aiCatalogCustomAndFoundationalItems'
        : 'aiCatalogItems';
    },
    resolvedItemTypes() {
      if (this.itemType !== AI_CATALOG_TYPE_AGENT) {
        return [this.itemType];
      }

      const itemTypes = [AI_CATALOG_TYPE_AGENT];

      if (this.glFeatures.aiCatalogThirdPartyFlows) {
        itemTypes.push(AI_CATALOG_TYPE_THIRD_PARTY_FLOW);
      }

      if (this.includeFoundationalItems) {
        itemTypes.push(AI_CATALOG_TYPE_FOUNDATIONAL_AGENT);
      }

      return itemTypes;
    },
    isLoading() {
      return this.$apollo.queries.aiCatalogItems.loading;
    },
    itemTypeConfig() {
      return {
        showRoute: this.itemRegistry.routes.show,
        visibilityTooltip: this.itemRegistry.visibilityDescriptions,
      };
    },
    ...sortingComputeds,
  },
  watch: {
    '$route.query.search': {
      handler(newSearch) {
        this.searchTerm = newSearch || '';
      },
    },
    '$route.query.sort': {
      handler(newSort) {
        this.sort = newSort || DEFAULT_SORT;
      },
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX, {
      label: this.itemRegistry.trackLabel,
    });
  },
  methods: {
    ...reactivePaginationMethods,
    handleFilter(filters) {
      const newSearch = filters.search || undefined;
      this.searchTerm = newSearch || '';
      this.resetPagination();
      if (this.$route.query.search !== newSearch) {
        this.$router.replace({
          query: { ...this.$route.query, search: newSearch },
        });
      }
    },
    handleSort(sortValue) {
      // FilteredSearchBar emits the fully-resolved sort string (e.g. 'STAR_COUNT_DESC'),
      // or the bare 'CATALOG_PRIORITY' for the directionless default.
      this.resetPagination();
      if (isSortDirectionless(sortValue)) {
        this.sort = DEFAULT_SORT;
        const { sort, ...rest } = this.$route.query;
        this.$router.replace({ query: rest });
        return;
      }
      this.sort = sortValue;
      this.$router.replace({
        query: { ...this.$route.query, sort: sortValue },
      });
    },
    dismissErrors() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header can-create />
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="dismissErrors" />

    <ai-catalog-list-wrapper
      :is-loading="isLoading"
      :items="aiCatalogItems"
      :item-type-config="itemTypeConfig"
      :page-info="pageInfo"
      :search-term="searchTerm"
      :initial-sort-by="initialSortBy"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
      @filter="handleFilter"
      @sort="handleSort"
    />
  </div>
</template>
