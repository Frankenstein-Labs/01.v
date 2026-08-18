<script>
import { defineAsyncComponent } from 'vue';
import { GlButton, GlSprintf, GlIcon, GlTooltipDirective, GlKeysetPagination } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, n__, sprintf } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { createAlert } from '~/alert';
import {
  getLocationHash,
  queryToObject,
  setUrlParams,
  updateHistory,
} from '~/lib/utils/url_utility';
import { smoothScrollTop } from '~/lib/utils/scroll_utils';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import SequentialCursorPaginator from '~/vue_shared/utils/sequential_cursor_pagination';
import { SIDEBAR_VISIBLE_STORAGE_KEY, MAX_SELECTED_COUNT } from '../constants';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import NamespaceSecurityProjectsQuery from '../graphql/namespace_security_projects.query.graphql';
import { getData, getPageInfo } from '../graphql/helper';
import SubgroupSidebar from './sidebar/subgroup_sidebar.vue';
import EmptyState from './empty_state.vue';
import SecurityInventoryTable from './security_inventory_table.vue';
import InventoryDashboardFilteredSearchBar from './inventory_dashboard_filtered_search_bar.vue';
import BulkEditActionsDropdown from './bulk_edit_actions_dropdown.vue';

const PAGE_SIZE = 20;

export default {
  components: {
    SubgroupSidebar,
    LocalStorageSync,
    RecursiveBreadcrumbs: defineAsyncComponent(() => import('./recursive_breadcrumbs.vue')),
    GlButton,
    GlSprintf,
    GlIcon,
    GlKeysetPagination,
    EmptyState,
    SecurityInventoryTable,
    InventoryDashboardFilteredSearchBar,
    BulkEditActionsDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'groupFullPath',
    'groupId',
    'newProjectPath',
    'canReadAttributes',
    'canManageAttributes',
    'canApplyProfiles',
  ],
  i18n: {
    errorFetchingChildren: s__(
      'SecurityInventory|An error occurred while fetching subgroups and projects. Please try again.',
    ),
    loadMore: s__('SecurityInventory|Load more'),
  },
  data() {
    return {
      activeFullPath: this.groupFullPath,
      activeGroupId: this.groupId,
      sidebarVisible: true,
      filters: {
        search: this.getSearchParams(),
      },
      // displayItems is the combined list of Project and Subgroups to be shown in the UI.
      displayItems: [],
      subgroupItems: [],
      projectItems: [],
      subgroupsPageInfo: {
        hasNextPage: false,
        endCursor: null,
      },
      projectsPageInfo: {
        hasNextPage: false,
        endCursor: null,
      },
      isLoadingMore: false,
      isLoadingNextPrev: false,
      projectsInitialized: false,
      selectedCount: 0,
      currentPage: [],
    };
  },
  apollo: {
    subgroupItems: {
      skip() {
        return this.useNewPagination || this.hasSearch;
      },
      query: SubgroupsAndProjectsQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.activeFullPath,
          canReadAttributes: this.canReadAttributes,
          subgroupsFirst: PAGE_SIZE,
          subgroupsAfter: null,
          projectsFirst: PAGE_SIZE,
          projectsAfter: null,
        };
      },
      update(data) {
        const groupData = getData(data, 'group');
        if (!groupData) return [];

        return getData(groupData, 'descendantGroups.nodes', []);
      },
      result({ data }) {
        const groupData = getData(data, 'group');
        if (!groupData) return;
        this.activeGroupId = groupData.id;

        this.subgroupsPageInfo = getPageInfo(groupData, 'descendantGroups.pageInfo');
        this.projectsPageInfo = getPageInfo(groupData, 'projects.pageInfo');

        const subgroups = getData(groupData, 'descendantGroups.nodes', []);
        this.projectItems = getData(groupData, 'projects.nodes', []);
        this.projectsInitialized = true;

        // Initially, populate items with only subgroups
        this.displayItems = [...subgroups];
        // Once all subgroups are loaded, display both subgroups and projects
        if (!this.hasMoreSubgroups) {
          this.displayItems = [...subgroups, ...this.projectItems];
        }
      },
      error(error) {
        this.handleError(error);
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    searchResults: {
      query: NamespaceSecurityProjectsQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      skip() {
        return this.useNewPagination || !this.hasSearch;
      },
      variables() {
        const {
          search = '',
          securityAnalyzerFilters = [],
          vulnerabilityCountFilters = [],
          attributeFilters = [],
          hasScanners = null,
          hasFailedOrWarning = null,
          hasStale = null,
        } = this.filters;

        return {
          fullPath: this.activeFullPath,
          namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.activeGroupId),
          canReadAttributes: this.canReadAttributes,
          search,
          securityAnalyzerFilters,
          vulnerabilityCountFilters,
          attributeFilters,
          hasScanners,
          hasFailedOrWarning,
          hasStale,
          projectsFirst: PAGE_SIZE,
          projectsAfter: null,
        };
      },
      update(data) {
        return getData(data, 'namespaceSecurityProjects.edges', []).map((edge) => edge.node);
      },
      result({ data }) {
        const groupData = getData(data, 'group');
        if (groupData) {
          this.activeGroupId = groupData.id;
        }

        this.projectsPageInfo = getPageInfo(data, 'namespaceSecurityProjects.pageInfo');
        const projects = getData(data, 'namespaceSecurityProjects.edges', []).map(
          (edge) => edge.node,
        );
        this.displayItems = [...projects];
      },
      error(error) {
        this.handleError(error);
      },
    },
  },
  computed: {
    hasMoreSubgroups() {
      return this.subgroupsPageInfo?.hasNextPage;
    },
    hasMoreProjects() {
      return this.projectsPageInfo?.hasNextPage;
    },
    isLoading() {
      // when loading more, keep table visible
      if (this.isLoadingMore) return false;

      // otherwise, show loading state when loading
      return (
        this.$apollo.queries.subgroupItems.loading ||
        this.$apollo.queries.searchResults.loading ||
        this.isLoadingNextPrev
      );
    },
    hasSearch() {
      return Boolean(
        this.filters.search?.length ||
        this.filters.securityAnalyzerFilters?.length ||
        this.filters.vulnerabilityCountFilters?.length ||
        this.filters.attributeFilters?.length ||
        this.filters.hasScanners != null ||
        this.filters.hasFailedOrWarning != null ||
        this.filters.hasStale != null,
      );
    },
    hasChildren() {
      return this.currentPage?.length > 0 || this.displayItems.length > 0;
    },
    showLoadMoreButton() {
      return (this.hasMoreSubgroups && !this.hasSearch) || this.hasMoreProjects;
    },
    showEmptyState() {
      return !this.isLoading && !this.hasChildren;
    },
    selectedCountMessage() {
      return sprintf(
        n__(
          '%{strongStart}%{selectedCount}%{strongEnd} item selected',
          '%{strongStart}%{selectedCount}%{strongEnd} items selected',
          this.selectedCount,
        ),
        { selectedCount: this.selectedCount },
      );
    },
    variables() {
      const {
        search = '',
        securityAnalyzerFilters = [],
        vulnerabilityCountFilters = [],
        attributeFilters = [],
        hasScanners = null,
        hasFailedOrWarning = null,
        hasStale = null,
      } = this.filters;

      return {
        fullPath: this.activeFullPath,
        namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.activeGroupId),
        search,
        hasSearch: this.hasSearch,
        securityAnalyzerFilters,
        vulnerabilityCountFilters,
        attributeFilters,
        hasScanners,
        hasFailedOrWarning,
        hasStale,
        canReadAttributes: this.canReadAttributes,
      };
    },
    useNewPagination() {
      return this.glFeatures.securityInventoryPagination;
    },
  },
  created() {
    if (this.useNewPagination) {
      this.paginator = new SequentialCursorPaginator(
        this.$apollo,
        [
          {
            query: SubgroupsAndProjectsQuery,
            skip: () => this.hasSearch,
            first: 'subgroupsFirst',
            last: 'subgroupsLast',
            after: 'subgroupsAfter',
            before: 'subgroupsBefore',
            getNodes: (result) => result.data.group.descendantGroups.nodes,
            getPageInfo: (result) => result.data.group.descendantGroups.pageInfo,
            baseVariables: { projectsFirst: 0 },
            timeout: 5000,
          },
          {
            query: NamespaceSecurityProjectsQuery,
            first: 'projectsFirst',
            last: 'projectsLast',
            after: 'projectsAfter',
            before: 'projectsBefore',
            getNodes: (result) =>
              result.data.namespaceSecurityProjects.edges.map((edge) => edge.node),
            getPageInfo: (result) => result.data.namespaceSecurityProjects.pageInfo,
            timeout: 5000,
          },
        ],
        20,
      );
    }

    this.debouncedFilter = debounce(this.performFilter, 50);
    this.initializeFromUrl();
    window.addEventListener('hashchange', this.handleLocationHashChange);
  },
  async mounted() {
    if (this.useNewPagination) {
      await this.withPaginationErrorHandling(() =>
        this.paginator.getNextCombinedPage(this.variables),
      );
    }
  },
  beforeDestroy() {
    window.removeEventListener('hashchange', this.handleLocationHashChange);
  },
  methods: {
    handleError(error) {
      createAlert({
        message: this.$options.i18n.errorFetchingChildren,
        error,
        captureError: true,
      });
      Sentry.captureException(error);
    },
    async withPaginationErrorHandling(paginationFn) {
      this.isLoadingNextPrev = true;
      try {
        smoothScrollTop();
        this.currentPage = await paginationFn();
      } catch (error) {
        this.handleError(error);
      } finally {
        this.isLoadingNextPrev = false;
      }
    },
    getSearchParams() {
      return queryToObject(window.location.search).search;
    },
    initializeFromUrl() {
      this.handleLocationHashChange();
      this.filters.search = this.getSearchParams();
    },
    async handleLocationHashChange() {
      let hash = getLocationHash();
      if (!hash) {
        hash = this.groupFullPath;
      }
      if (this.activeFullPath !== hash) {
        this.activeFullPath = hash;
        this.$refs.inventoryTable?.clearSelection();
        this.resetData();

        if (this.useNewPagination) {
          await this.withPaginationErrorHandling(() => this.paginator?.reset(this.variables));
        }
      }
    },
    resetData() {
      this.displayItems = [];
      this.subgroupItems = [];
      this.projectItems = [];
      this.subgroupsPageInfo = {
        hasNextPage: false,
        endCursor: null,
      };
      this.projectsPageInfo = {
        hasNextPage: false,
        endCursor: null,
      };
      this.isLoadingMore = false;
      this.projectsInitialized = false;
    },
    async loadMore() {
      if (this.isLoadingMore) return;
      this.isLoadingMore = true;

      try {
        if (this.hasSearch) {
          await this.loadMoreSearchResults();
        } else if (this.hasMoreSubgroups) {
          await this.loadMoreSubgroups();
        } else {
          await this.loadMoreProjects();
        }
      } catch (error) {
        this.handleError(error);
      } finally {
        this.isLoadingMore = false;
      }
    },
    /**
     * Abstracts the GraphQL query for fetching subgroups and projects
     * @param {Object} options - Query options
     * @param {Number} options.subgroupsFirst - Number of subgroups to fetch
     * @param {String} options.subgroupsAfter - Cursor for subgroups pagination
     * @param {Number} options.projectsFirst - Number of projects to fetch
     * @param {String} options.projectsAfter - Cursor for projects pagination
     * @returns {Promise} Apollo query promise
     */
    async fetchSubgroupsAndProjects(options = {}) {
      const {
        subgroupsFirst = 0,
        subgroupsAfter = null,
        projectsFirst = 0,
        projectsAfter = null,
      } = options;

      return this.$apollo.query({
        query: SubgroupsAndProjectsQuery,
        variables: {
          fullPath: this.activeFullPath,
          subgroupsFirst,
          subgroupsAfter,
          projectsFirst,
          projectsAfter,
          canReadAttributes: this.canReadAttributes,
        },
      });
    },
    async loadMoreSubgroups() {
      const { data } = await this.fetchSubgroupsAndProjects({
        subgroupsFirst: PAGE_SIZE,
        subgroupsAfter: this.subgroupsPageInfo.endCursor,
      });

      const groupData = getData(data, 'group');
      if (!groupData) return;

      const newSubgroups = getData(groupData, 'descendantGroups.nodes', []);
      this.subgroupsPageInfo = getPageInfo(groupData, 'descendantGroups.pageInfo');
      this.subgroupItems = [...this.subgroupItems, ...newSubgroups];

      if (!this.hasMoreSubgroups) {
        this.displayItems = [...this.subgroupItems, ...this.projectItems];
      } else {
        this.displayItems = [...this.subgroupItems];
      }
    },
    async loadMoreProjects() {
      const { data } = await this.fetchSubgroupsAndProjects({
        projectsFirst: PAGE_SIZE,
        projectsAfter: this.projectsPageInfo.endCursor,
      });

      const groupData = getData(data, 'group');
      if (!groupData) return;

      const newProjects = getData(groupData, 'projects.nodes', []);
      this.projectsPageInfo = getPageInfo(groupData, 'projects.pageInfo');
      this.projectItems = [...this.projectItems, ...newProjects];

      this.displayItems = [...this.subgroupItems, ...this.projectItems];
    },
    /**
     * Fetches more search results using the NamespaceSecurityProjectsQuery
     * @param {Object} options - Query options
     * @param {Number} options.projectsFirst - Number of projects to fetch
     * @param {String} options.projectsAfter - Cursor for projects pagination
     * @returns {Promise} Apollo query promise
     */
    async fetchSecurityProjects(options = {}) {
      const { projectsFirst = 0, projectsAfter = null } = options;
      const {
        search = '',
        securityAnalyzerFilters = [],
        vulnerabilityCountFilters = [],
        attributeFilters = [],
        hasScanners = null,
        hasFailedOrWarning = null,
        hasStale = null,
      } = this.filters;

      return this.$apollo.query({
        query: NamespaceSecurityProjectsQuery,
        variables: {
          fullPath: this.activeFullPath,
          namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.activeGroupId),
          search,
          securityAnalyzerFilters,
          vulnerabilityCountFilters,
          attributeFilters,
          hasScanners,
          hasFailedOrWarning,
          hasStale,
          canReadAttributes: this.canReadAttributes,
          projectsFirst,
          projectsAfter,
        },
      });
    },
    async loadMoreSearchResults() {
      const { data } = await this.fetchSecurityProjects({
        projectsFirst: PAGE_SIZE,
        projectsAfter: this.projectsPageInfo.endCursor,
      });

      const newProjects = getData(data, 'namespaceSecurityProjects.edges', []).map((e) => e.node);
      this.projectsPageInfo = getPageInfo(data, 'namespaceSecurityProjects.pageInfo');
      this.searchResults = [...this.searchResults, ...newProjects];

      this.displayItems = [...this.searchResults];
    },
    async refetchData() {
      if (this.useNewPagination) {
        await this.withPaginationErrorHandling(() => this.paginator.refetch(this.variables));
      } else if (this.hasSearch) {
        this.$apollo.queries.searchResults.refetch();
      } else {
        this.$apollo.queries.subgroupItems.refetch();
      }
    },
    toggleSidebar(value = !this.sidebarVisible) {
      this.sidebarVisible = value;
    },
    filterSubgroupsAndProjects(filters) {
      this.filters = filters;
      this.debouncedFilter(filters);
      this.$refs.inventoryTable?.clearSelection();
    },
    async performFilter(filters) {
      const currentHash = getLocationHash();
      const newUrl = setUrlParams(
        { search: filters.search },
        { url: window.location.href, clearParams: true },
      );
      const urlWithHashPreserved = newUrl.split('#')[0] + (currentHash ? `#${currentHash}` : '');
      updateHistory({
        url: urlWithHashPreserved,
      });
      if (this.useNewPagination) {
        await this.withPaginationErrorHandling(() => this.paginator?.reset(this.variables));
      }
    },
    bulkEdit(type) {
      this.$nextTick(() => {
        this.$refs.inventoryTable.bulkEdit(type);
      });
    },
    handleSelectedCount(count) {
      this.selectedCount = count;
    },
    async handleNextPage() {
      await this.withPaginationErrorHandling(() =>
        this.paginator.getNextCombinedPage(this.variables),
      );
    },
    async handlePreviousPage() {
      await this.withPaginationErrorHandling(() =>
        this.paginator.getPreviousCombinedPage(this.variables),
      );
    },
  },
  SIDEBAR_VISIBLE_STORAGE_KEY,
  MAX_SELECTED_COUNT,
};
</script>

<template>
  <div class="-gl-mb-10 gl-mt-5">
    <div
      class="gl-flex gl-w-full gl-border-b-1 gl-border-t-1 gl-border-default gl-bg-subtle gl-border-b-solid gl-border-t-solid"
    >
      <gl-button
        icon="sidebar"
        icon-only
        class="gl-m-3"
        :aria-label="sidebarVisible ? __('Collapse sidebar') : __('Expand sidebar')"
        @click="toggleSidebar()"
      />
      <inventory-dashboard-filtered-search-bar
        class="gl-flex-auto gl-items-center"
        :initial-filters="filters"
        :namespace="activeFullPath"
        show-status-filter
        @filter-subgroups-and-projects="filterSubgroupsAndProjects"
      />
    </div>
    <local-storage-sync
      v-model="sidebarVisible"
      :storage-key="$options.SIDEBAR_VISIBLE_STORAGE_KEY"
      @input="toggleSidebar"
    />
    <div class="gl-flex">
      <subgroup-sidebar v-if="sidebarVisible" :active-full-path="activeFullPath" />
      <div class="gl-w-auto gl-grow" :class="{ 'gl-pl-5': sidebarVisible }">
        <div
          v-if="selectedCount"
          class="gl-border-b gl-sticky gl-top-0 gl-z-2 gl-flex gl-flex-row gl-items-center gl-justify-between gl-bg-default gl-px-3 gl-py-4"
        >
          <span>
            <gl-sprintf :message="selectedCountMessage">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
            <gl-icon
              v-if="selectedCount >= $options.MAX_SELECTED_COUNT"
              v-gl-tooltip="
                sprintf(__('You can edit up to %{maximumCount} items at once'), {
                  maximumCount: $options.MAX_SELECTED_COUNT,
                })
              "
              name="warning"
              variant="warning"
            />
          </span>
          <bulk-edit-actions-dropdown
            v-if="glFeatures.securityScanProfilesFeature && canApplyProfiles"
            :selected-count="selectedCount"
            @bulk-edit="bulkEdit"
          />
          <gl-button
            v-else-if="canManageAttributes"
            data-testid="edit-attributes-button"
            @click="bulkEdit"
            >{{ s__('SecurityAttributes|Edit security attributes') }}</gl-button
          >
        </div>
        <recursive-breadcrumbs
          v-else
          :group-full-path="groupFullPath"
          :current-path="activeFullPath"
        />
        <empty-state v-if="showEmptyState" />
        <security-inventory-table
          v-else
          ref="inventoryTable"
          :items="useNewPagination ? currentPage : displayItems"
          :is-loading="isLoading"
          :has-search="hasSearch"
          :current-path="activeFullPath"
          @refetch="refetchData"
          @selected-count="handleSelectedCount"
        />
        <template v-if="useNewPagination">
          <gl-keyset-pagination
            :has-next-page="paginator?.hasNextPage()"
            :has-previous-page="paginator?.hasPreviousPage()"
            class="gl-my-2 gl-text-center"
            @prev="handlePreviousPage"
            @next="handleNextPage"
          />
        </template>
        <div v-else-if="showLoadMoreButton" class="gl-mt-5 gl-flex gl-justify-center">
          <gl-button data-testid="load-more-button" :loading="isLoadingMore" @click="loadMore">
            {{ $options.i18n.loadMore }}
          </gl-button>
        </div>
      </div>
    </div>
  </div>
</template>
