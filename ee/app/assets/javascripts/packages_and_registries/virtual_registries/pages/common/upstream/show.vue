<script>
import { GlEmptyState, GlSkeletonLoader, GlFilteredSearch, GlKeysetPagination } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { deleteMavenUpstreamCacheEntry } from 'ee/api/virtual_registries_api';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { setUrlParams, updateHistory, queryToObject } from '~/lib/utils/url_utility';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/show/header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/show/cache_entries_table.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { s__ } from '~/locale';

const PAGE_SIZE = 20;
const INITIAL_PAGE_PARAMS = {
  first: PAGE_SIZE,
};

export default {
  name: 'UpstreamShow',
  components: {
    GlEmptyState,
    CacheEntriesTable,
    GlSkeletonLoader,
    GlFilteredSearch,
    GlKeysetPagination,
    UpstreamDetailsHeader,
  },
  inject: {
    initialUpstream: { default: {} },
    ids: { default: {} },
    getUpstreamSummaryQuery: { default: null },
    getUpstreamCacheEntriesCountQuery: { default: null },
    getUpstreamCacheEntriesQuery: { default: null },
    deleteCacheEntryMutation: { default: null },
  },
  props: {
    id: {
      type: [Number, String],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      cacheEntries: {
        nodes: [],
        pageInfo: {},
      },
      cacheEntriesCount: 0,
      upstream: this.initialUpstream || {},
      upstreamId: convertToGraphQLId(this.ids.baseUpstream, this.id || this.initialUpstream.id),
      urlParams: null,
      pageParams: INITIAL_PAGE_PARAMS,
    };
  },
  apollo: {
    upstream: {
      query() {
        return this.getUpstreamSummaryQuery;
      },
      skip() {
        return Object.keys(this.initialUpstream).length;
      },
      variables() {
        return {
          id: this.upstreamId,
        };
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
    cacheEntries: {
      query() {
        return this.getUpstreamCacheEntriesQuery;
      },
      variables() {
        return this.queryVariables;
      },
      skip() {
        return this.urlParams === null;
      },
      update: (data) =>
        data.upstream?.cacheEntries ?? {
          nodes: [],
          pageInfo: {},
        },
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries.'),
          error,
          captureError: true,
        });
      },
    },
    cacheEntriesCount: {
      query() {
        return this.getUpstreamCacheEntriesCountQuery;
      },
      variables() {
        return {
          id: this.upstreamId,
        };
      },
      skip() {
        return this.urlParams === null;
      },
      update: (data) => data.upstream?.cacheEntries?.count ?? 0,
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries count.'),
          error,
          captureError: true,
        });
      },
    },
  },
  computed: {
    filteredSearchValue() {
      return [
        {
          type: 'filtered-search-term',
          value: { data: this.urlParams.search || '' },
        },
      ];
    },
    queryVariables() {
      return {
        id: this.upstreamId,
        ...this.urlParams,
        ...this.pageParams,
      };
    },
  },
  watch: {
    $route(to) {
      this.setQueryVariables(to.query);
    },
  },
  created() {
    this.setQueryVariables(queryToObject(window.location.search));
  },
  methods: {
    setQueryVariables(queryStringObject) {
      if (queryStringObject.after || queryStringObject.before) {
        this.pageParams = this.buildPageParams(queryStringObject);
      } else {
        this.pageParams = INITIAL_PAGE_PARAMS;
      }

      this.urlParams = queryStringObject.search ? { search: queryStringObject.search } : {};
    },
    async handleDeleteCacheEntry({ id }) {
      try {
        if (this.deleteCacheEntryMutation) {
          const { data } = await this.$apollo.mutate({
            mutation: this.deleteCacheEntryMutation,
            variables: {
              id,
            },
          });

          if (data.delete?.errors?.length) {
            throw data.delete.errors[0];
          }
        } else {
          await deleteMavenUpstreamCacheEntry({
            id,
          });
        }
        this.pageParams = INITIAL_PAGE_PARAMS;
        this.$apollo.queries.cacheEntriesCount.refetch();
        this.$apollo.queries.cacheEntries.refetch();
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to delete cache entry.'),
          error,
          captureError: true,
        });
      }
    },
    searchCacheEntries(filters) {
      const searchTerm = filters[0];
      this.urlParams = { search: searchTerm };
      this.updateUrlAndPageParams(this.urlParams, INITIAL_PAGE_PARAMS);
    },
    buildPageParams(pageInfo) {
      return getPageParams(pageInfo, PAGE_SIZE);
    },
    handleNextPage() {
      const urlParams = { after: this.cacheEntries.pageInfo.endCursor };
      const pageParams = this.buildPageParams(urlParams);

      this.updateUrlAndPageParams(urlParams, pageParams);
    },
    handlePreviousPage() {
      const urlParams = { before: this.cacheEntries.pageInfo.startCursor };
      const pageParams = this.buildPageParams(urlParams);

      this.updateUrlAndPageParams(urlParams, pageParams);
    },
    updateUrlAndPageParams(params, pageParams) {
      this.pageParams = pageParams;

      const updatedParams = {
        ...params,
        ...(this.urlParams.search && { search: this.urlParams.search }),
      };

      if (this.$router) {
        this.$router.push({ query: { ...updatedParams } });
      } else {
        updateHistory({
          url: setUrlParams(updatedParams, { url: window.location.href, clearParams: true }),
        });
      }
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <gl-skeleton-loader
      v-if="$apollo.queries.upstream.loading"
      :lines="2"
      :width="500"
      class="gl-mt-4"
    />
    <template v-else-if="upstream">
      <upstream-details-header
        :upstream="upstream"
        :loading="$apollo.queries.cacheEntriesCount.loading"
        :cache-entries-count="cacheEntriesCount"
      />

      <div
        class="gl-border-t gl-flex gl-flex-col gl-gap-3 gl-bg-subtle gl-p-5 @md/panel:gl-flex-row"
      >
        <gl-filtered-search
          class="gl-min-w-0 gl-grow"
          :placeholder="__('Filter results')"
          :search-text-option-label="__('Search for this text')"
          :value="filteredSearchValue"
          terms-as-tokens
          @submit="searchCacheEntries"
          @clear="searchCacheEntries([''])"
        />
      </div>

      <cache-entries-table
        :cache-entries="cacheEntries.nodes"
        :loading="$apollo.queries.cacheEntries.loading"
        @delete="handleDeleteCacheEntry"
      />

      <div class="gl-flex gl-justify-center">
        <gl-keyset-pagination
          v-bind="cacheEntries.pageInfo"
          @next="handleNextPage"
          @prev="handlePreviousPage"
        />
      </div>
    </template>
    <template v-else>
      <gl-empty-state
        :title="s__('Virtual registry|Upstream not found.')"
        :svg-path="$options.emptySearchSvg"
      />
    </template>
  </div>
</template>
