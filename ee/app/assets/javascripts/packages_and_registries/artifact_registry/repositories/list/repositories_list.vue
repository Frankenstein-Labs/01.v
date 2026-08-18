<script>
import emptyStateSvgPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-package-md.svg';
import { GlAlert, GlButton, GlEmptyState, GlKeysetPagination } from '@gitlab/ui';
import { isEqual, isNil, mapValues, omit, omitBy } from 'lodash-es';
import { fetchPolicies } from '~/lib/graphql';
import { getStorageValue } from '~/lib/utils/local_storage';
import { __, s__ } from '~/locale';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import NotFound from '../../components/not_found.vue';
import {
  GRAPHQL_PAGE_SIZE,
  PAGE_NOT_FOUND_TITLE,
  REPOSITORIES_SORT_STORAGE_KEY,
  REPOSITORY_FORMAT_VALUES,
  REPOSITORY_KIND_VALUES,
  REPOSITORY_SORT_DEFAULT,
  REPOSITORY_SORT_VALUES,
} from '../../constants';
import { toFilterEnumValue, toFilterQueryValue, toSortEnumValue, toTableSort } from '../../utils';
import getRepositoriesQuery from '../../graphql/queries/get_repositories.query.graphql';
import RepositoriesHeader from './repositories_header.vue';
import RepositoriesTable from './repositories_table.vue';
import RepositoriesToolbar from './repositories_toolbar.vue';

// `getPageParams` reads the two cursors back out of the route query under these keys.
const CURSOR_QUERY_KEYS = ['after', 'before'];

export default {
  name: 'ArtifactRegistryRepositoriesList',
  components: {
    GlAlert,
    GlButton,
    GlEmptyState,
    GlKeysetPagination,
    LocalStorageSync,
    NotFound,
    RepositoriesHeader,
    RepositoriesTable,
    RepositoriesToolbar,
  },
  inject: ['organizationGid'],
  data() {
    const { value } = getStorageValue(REPOSITORIES_SORT_STORAGE_KEY);

    return {
      repositoriesConnection: undefined,
      hasError: false,
      // Read here rather than in a hook: the smart query below is created before any of
      // them and reads `sortValue`, so a stored sort arriving later sends the default
      // first and has that request cancelled.
      storedSort: REPOSITORY_SORT_VALUES.includes(value) ? value : null,
    };
  },
  apollo: {
    repositoriesConnection: {
      query: getRepositoriesQuery,
      // The cache keys the connection on its filters and sort, so every page of one
      // selection shares an entry and a cache-first read would answer a page change
      // with the page already held.
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          organizationId: this.organizationGid,
          ...this.filters,
          sort: this.sortValue,
          first: GRAPHQL_PAGE_SIZE,
          // A backward page asks for `last` and carries `first: undefined`, so the page
          // params have to land after the default rather than beside it.
          ...this.pageParams,
        };
      },
      update: ({ organization }) => organization?.artifactRegistryRepositories ?? null,
      error() {
        this.hasError = true;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.repositoriesConnection.loading;
    },
    hasResult() {
      return !this.isLoading && !this.hasError;
    },
    isUnavailable() {
      return !this.isLoading && this.hasError;
    },
    // The connection resolves null for a namespace the viewer cannot see, so the view
    // renders the not-found state alone rather than confirming the namespace exists.
    isNotFound() {
      return this.hasResult && this.repositoriesConnection === null;
    },
    repositories() {
      return this.repositoriesConnection?.nodes ?? [];
    },
    pageInfo() {
      return this.repositoriesConnection?.pageInfo ?? {};
    },
    pageParams() {
      return getPageParams(this.$route.query, GRAPHQL_PAGE_SIZE);
    },
    filters() {
      const { format, kind } = this.$route.query;

      return {
        format: toFilterEnumValue(format, REPOSITORY_FORMAT_VALUES),
        kind: toFilterEnumValue(kind, REPOSITORY_KIND_VALUES),
      };
    },
    // The query wins over the stored preference, so a shared link renders the sort it
    // names whatever the recipient has stored.
    sortValue() {
      return (
        toFilterEnumValue(this.$route.query.sort, REPOSITORY_SORT_VALUES) ??
        this.storedSort ??
        REPOSITORY_SORT_DEFAULT
      );
    },
    sort() {
      return toTableSort(this.sortValue);
    },
    hasFilters() {
      return Object.values(this.filters).some((value) => value !== null);
    },
    hasNoRepositories() {
      return this.hasResult && !this.isNotFound && this.repositories.length === 0;
    },
    isEmpty() {
      return this.hasNoRepositories && !this.hasFilters;
    },
    isZeroResult() {
      return this.hasNoRepositories && this.hasFilters;
    },
    resultMessage() {
      if (this.isLoading) return this.$options.i18n.loading;
      if (this.isUnavailable) return this.$options.i18n.unavailable;
      if (this.isNotFound) return this.$options.i18n.notFound;
      if (this.isZeroResult) return this.$options.i18n.zeroResultAnnouncement;
      if (this.isEmpty) return this.$options.i18n.emptyDescription;

      return this.$options.i18n.updated;
    },
  },
  created() {
    this.restoreStoredSort();
  },
  methods: {
    // vue-router rejects a push to the route it already holds, so a navigation that
    // would leave the query as it is does not happen at all.
    pushQuery(query) {
      if (isEqual(query, this.$route.query)) return;

      this.$router.push({ path: this.$route.path, query });
    },
    // The cursor is an opaque keyset over the active page, so it cannot carry across a
    // change to what is being paged. Dropping it whenever the rest of the query changes
    // resets to the first page without enumerating which keys the page writes.
    // Named for the route query rather than the filters, because the sort travels it too.
    applyQueryParams(params) {
      const remainder = omit(this.$route.query, CURSOR_QUERY_KEYS);
      const applied = mapValues(params, toFilterQueryValue);
      const query = omitBy({ ...remainder, ...applied }, isNil);

      // An unchanged selection keeps the active cursor, which `remainder` has dropped.
      if (isEqual(query, remainder)) return;

      this.pushQuery(query);
    },
    applyFilters(filters) {
      this.applyQueryParams(filters);
    },
    applySort(sort) {
      this.applyQueryParams({ sort: toSortEnumValue(sort) });
    },
    clearFilters() {
      this.applyFilters({ format: null, kind: null });
    },
    // A page is reached forward or backward, never both, so writing one cursor drops
    // the other. Holding it in the route query is what makes a page shareable and
    // survive a reload.
    goToPage(cursor) {
      const remainder = omit(this.$route.query, CURSOR_QUERY_KEYS);

      this.pushQuery(omitBy({ ...remainder, ...cursor }, isNil));
    },
    nextPage(endCursor) {
      this.goToPage({ after: endCursor });
    },
    previousPage(startCursor) {
      this.goToPage({ before: startCursor });
    },
    // `sortValue` already renders the stored sort; this only brings the URL into line so
    // the order is shareable. An absent `sort` already renders the default.
    restoreStoredSort() {
      if (this.$route.query.sort) return;
      if (!this.storedSort || this.storedSort === REPOSITORY_SORT_DEFAULT) return;

      // The cursor was cut against a different order. Replacing keeps arrival off the
      // back stack.
      const remainder = omit(this.$route.query, CURSOR_QUERY_KEYS);

      this.$router.replace({
        path: this.$route.path,
        query: { ...remainder, sort: toFilterQueryValue(this.storedSort) },
      });
    },
  },
  sortStorageKey: REPOSITORIES_SORT_STORAGE_KEY,
  emptyStateSvgPath,
  i18n: {
    emptyTitle: s__('ArtifactRegistry|No repositories'),
    emptyDescription: s__('ArtifactRegistry|This organization has no repositories yet.'),
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
    loading: s__('ArtifactRegistry|Loading repositories.'),
    updated: s__('ArtifactRegistry|Repositories list updated.'),
    notFound: PAGE_NOT_FOUND_TITLE,
    zeroResultTitle: __('No results found'),
    zeroResultDescription: s__(
      'ArtifactRegistry|Edit or clear your filters to see more repositories.',
    ),
    // The live region reads the filtered miss in the view's own terms: "No results
    // found" alone does not say what was searched.
    zeroResultAnnouncement: s__('ArtifactRegistry|No repositories match your filters.'),
    clearFilters: __('Clear filters'),
  },
};
</script>

<template>
  <div>
    <span
      class="gl-sr-only"
      aria-live="polite"
      aria-atomic="true"
      data-testid="result-announcement"
      >{{ resultMessage }}</span
    >

    <!-- Write-only, with no listener for the restore this emits on mount: the page has
         already read the stored sort itself by then. -->
    <local-storage-sync :storage-key="$options.sortStorageKey" :value="sortValue" />

    <not-found v-if="isNotFound" />

    <template v-else>
      <repositories-header />

      <gl-alert v-if="isUnavailable" variant="danger" :dismissible="false">
        {{ $options.i18n.unavailable }}
      </gl-alert>

      <gl-empty-state
        v-else-if="isEmpty"
        :svg-path="$options.emptyStateSvgPath"
        :title="$options.i18n.emptyTitle"
        :description="$options.i18n.emptyDescription"
      />

      <template v-else>
        <repositories-toolbar :filters="filters" @apply-filter="applyFilters" />

        <gl-empty-state
          v-if="isZeroResult"
          :svg-path="$options.emptyStateSvgPath"
          :title="$options.i18n.zeroResultTitle"
          :description="$options.i18n.zeroResultDescription"
        >
          <template #actions>
            <gl-button data-testid="clear-filters" @click="clearFilters">
              {{ $options.i18n.clearFilters }}
            </gl-button>
          </template>
        </gl-empty-state>

        <template v-else>
          <repositories-table
            :repositories="repositories"
            :sort="sort"
            :is-loading="isLoading"
            @sort-changed="applySort"
          />

          <div class="gl-mt-3 gl-flex gl-justify-center">
            <gl-keyset-pagination v-bind="pageInfo" @prev="previousPage" @next="nextPage" />
          </div>
        </template>
      </template>
    </template>
  </div>
</template>
