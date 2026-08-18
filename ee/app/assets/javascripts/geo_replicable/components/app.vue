<script>
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import replicableTypeBulkUpdateMutation from 'ee/geo_shared/graphql/replicable_type_bulk_update_mutation.graphql';
import { sprintf, s__, n__ } from '~/locale';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import {
  visitUrl,
  pathSegments,
  queryToObject,
  setUrlParams,
  updateHistory,
} from '~/lib/utils/url_utility';
import {
  isValidFilter,
  getReplicationStatusFilter,
  getVerificationStatusFilter,
  getReplicableTypeFilter,
  processFilters,
  getGraphqlFilterVariables,
  getSortVariableString,
  getPaginationObject,
  getSortObject,
} from '../filters';
import { getGraphqlBulkMutationVariables } from '../mutations';
import {
  REPLICATION_STATUS_STATES_ARRAY,
  VERIFICATION_STATUS_STATES_ARRAY,
  TOKEN_TYPES,
  BULK_ACTIONS,
  GEO_TROUBLESHOOTING_LINK,
  DEFAULT_PAGE_SIZE,
  DEFAULT_CURSOR,
  DEFAULT_SORT,
} from '../constants';
import buildReplicableTypeQuery from '../graphql/replicable_type_query_builder';
import GeoReplicable from './geo_replicable.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GeoListTopBar,
    GeoReplicable,
    GeoList,
  },
  inject: {
    itemTitle: {
      default: '',
    },
    siteName: {
      default: '',
    },
    replicableClass: {
      default: {},
    },
  },
  data() {
    return {
      activeFilters: [],
      replicableItems: [],
      cursor: {},
      pageInfo: {},
      activeSort: DEFAULT_SORT,
    };
  },
  apollo: {
    replicableItems: {
      query() {
        return buildReplicableTypeQuery({
          graphqlFieldName: this.replicableClass.graphqlFieldName,
          graphqlRegistryIdType: this.replicableClass.graphqlRegistryIdType,
          verificationEnabled: this.replicableClass.verificationEnabled,
        });
      },
      variables() {
        return {
          sort: getSortVariableString(this.activeSort).toUpperCase(),
          ...this.cursor,
          ...getGraphqlFilterVariables({
            filters: this.activeFilteredSearchFilters,
            graphqlRegistryClass: this.replicableClass.graphqlRegistryClass,
          }),
        };
      },
      result({ data }) {
        const pageInfo = data?.geoNode?.[this.replicableClass.graphqlFieldName]?.pageInfo || {};
        const count = data?.geoNode?.[this.replicableClass.graphqlFieldName]?.count || 0;

        this.pageInfo = { ...pageInfo, count };
      },
      update(data) {
        const res = data?.geoNode?.[this.replicableClass.graphqlFieldName]?.nodes || [];
        return res;
      },
      error(error) {
        createAlert({
          message: sprintf(
            s__(
              'Geo|There was an error fetching the %{replicableType}. The GraphQL API call to the secondary may have failed.',
            ),
            { replicableType: this.itemTitle },
          ),
          error,
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.replicableItems.loading;
    },
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
    activeReplicableType() {
      const activeFilter = this.activeFilters.find(
        ({ type }) => type === TOKEN_TYPES.REPLICABLE_TYPE,
      );

      return activeFilter?.value;
    },
    activeFilteredSearchFilters() {
      return this.activeFilters.filter(({ type }) => type !== TOKEN_TYPES.REPLICABLE_TYPE);
    },
    emptyStateHasFilters() {
      return Boolean(this.activeFilteredSearchFilters.length);
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|No %{itemTitle} exist'), {
          itemTitle: this.itemTitle,
        }),
        description: s__(
          'Geo|If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        ),
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.emptyStateHasFilters,
      };
    },
    pageHeadingTitle() {
      return sprintf(s__('Geo|Geo replication - %{siteName}'), { siteName: this.siteName });
    },
    humanizedPageCount() {
      if (!this.pageInfo.count) {
        return null;
      }

      return this.pageInfo.count > 1000
        ? s__('Geo|1000+ Registries')
        : n__('Geo|%d Registry', 'Geo|%d Registries', this.pageInfo.count);
    },
  },
  created() {
    this.getFiltersFromQuery();
    this.getPaginationFromQuery();
    this.getSortFromQuery();
  },
  methods: {
    getFiltersFromQuery() {
      const filters = [];
      const url = new URL(window.location.href);
      const segments = pathSegments(url);
      const {
        ids,
        replication_status: replicationStatus,
        verification_status: verificationStatus,
      } = queryToObject(window.location.search || '');

      if (ids) {
        filters.push(ids);
      }

      if (isValidFilter(replicationStatus, REPLICATION_STATUS_STATES_ARRAY)) {
        filters.push(getReplicationStatusFilter(replicationStatus));
      }

      if (
        this.replicableClass.verificationEnabled &&
        isValidFilter(verificationStatus, VERIFICATION_STATUS_STATES_ARRAY)
      ) {
        filters.push(getVerificationStatusFilter(verificationStatus));
      }

      this.activeFilters = [getReplicableTypeFilter(segments.pop()), ...filters];
    },
    getPaginationFromQuery() {
      const { before, after, first, last } = queryToObject(window.location.search || '');
      this.cursor = getPaginationObject({ before, after, first, last });
    },
    getSortFromQuery() {
      const { sort } = queryToObject(window.location.search || '');

      if (sort) {
        this.activeSort = getSortObject(sort);
      }
    },
    handleListboxChange(val) {
      // This updates the replicable type filter which needs to re-interpolate the GraphQL Query
      // in graphql/replicable_type_query_builder.js so we redirect the page
      this.activeFilters = [getReplicableTypeFilter(val), ...this.activeFilteredSearchFilters];
      this.cursor = DEFAULT_CURSOR;

      this.updateUrl({ redirect: true });
    },
    handleSearch(filters) {
      this.activeFilters = [getReplicableTypeFilter(this.activeReplicableType), ...filters];
      this.cursor = DEFAULT_CURSOR;

      this.updateUrl({ redirect: false });
    },
    updateUrl({ redirect }) {
      const { query, url } = processFilters(this.activeFilters);
      const urlWithParams = setUrlParams(
        { ...query, ...this.cursor, sort: getSortVariableString(this.activeSort) },
        { url: url.href, clearParams: true },
      );

      if (redirect) {
        visitUrl(urlWithParams);
      } else {
        updateHistory({ url: urlWithParams });
      }
    },
    async handleSingleAction({ action, name, registryId }) {
      const actionName = action.toLowerCase();

      try {
        await this.$apollo.mutate({
          mutation: replicableTypeUpdateMutation,
          variables: {
            action: action.toUpperCase(),
            registryId,
          },
        });

        toast(sprintf(s__('Geo|Scheduled %{name} for %{actionName}.'), { name, actionName }));
        this.$apollo.queries.replicableItems.refetch();
      } catch (error) {
        createAlert({
          message: sprintf(s__('Geo|There was an error scheduling %{name} for %{actionName}.'), {
            name,
            actionName,
          }),
          error,
          captureError: true,
        });
      }
    },
    async handleBulkAction(bulkAction) {
      try {
        await this.$apollo.mutate({
          mutation: replicableTypeBulkUpdateMutation,
          variables: getGraphqlBulkMutationVariables({
            action: bulkAction.action,
            registryClass: this.replicableClass.graphqlMutationRegistryClass,
          }),
        });

        toast(sprintf(bulkAction.successMessage, { replicableType: this.itemTitle }));
        this.$apollo.queries.replicableItems.refetch();
      } catch (error) {
        createAlert({
          message: sprintf(bulkAction.errorMessage, { replicableType: this.itemTitle }),
          error,
          captureError: true,
        });
      }
    },
    handleNextPage(item) {
      this.cursor = {
        before: '',
        after: item,
        first: DEFAULT_PAGE_SIZE,
        last: null,
      };

      this.updateUrl({ redirect: false });
    },
    handlePrevPage(item) {
      this.cursor = {
        before: item,
        after: '',
        first: null,
        last: DEFAULT_PAGE_SIZE,
      };

      this.updateUrl({ redirect: false });
    },
    handleSort({ value, direction }) {
      this.activeSort = { value, direction };
      this.cursor = DEFAULT_CURSOR;

      this.updateUrl({ redirect: false });
    },
  },
  BULK_ACTIONS,
};
</script>

<template>
  <article class="geo-replicable-container">
    <geo-list-top-bar
      :page-heading-title="pageHeadingTitle"
      :page-heading-description="
        s__(
          'Geo|Review replication status, and resynchronize and reverify items with the primary site.',
        )
      "
      list-count-icon="earth"
      :list-count-text="humanizedPageCount"
      :listbox-header-text="s__('Geo|Select replicable type')"
      :active-listbox-item="activeReplicableType"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      :filtered-search-option-label="__('Search by ID')"
      :active-sort="activeSort"
      :show-actions="hasReplicableItems"
      :bulk-actions="$options.BULK_ACTIONS"
      @listbox-change="handleListboxChange"
      @search="handleSearch"
      @sort="handleSort"
      @bulk-action="handleBulkAction"
    />

    <geo-list :is-loading="isLoading" :has-items="hasReplicableItems" :empty-state="emptyState">
      <geo-replicable
        :replicable-items="replicableItems"
        :page-info="pageInfo"
        @action-clicked="handleSingleAction"
        @next="handleNextPage"
        @prev="handlePrevPage"
      />
    </geo-list>
  </article>
</template>
