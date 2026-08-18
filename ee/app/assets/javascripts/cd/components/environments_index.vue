<script>
import { GlButton, GlEmptyState, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { produce } from 'immer';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { ENVIRONMENT_FILTERS, ENVIRONMENTS_PAGE_SIZE, STATUS_ALL } from '../constants';
import cdEnvironmentsQuery from '../graphql/cd_environments.query.graphql';
import EnvironmentList from './environment_list.vue';
import NewEnvironmentPanel from './new_environment_panel.vue';
import FilterBar from './shared/filter_bar.vue';

export default {
  name: 'EnvironmentsIndex',
  components: {
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    EnvironmentList,
    NewEnvironmentPanel,
    PageHeading,
    FilterBar,
    GlSprintf,
  },
  i18n: {
    title: s__('ContinuousDeployment|Environments'),
    registerEnvironment: s__('ContinuousDeployment|Register environment'),
    environmentsCountLabel: s__(
      'ContinuousDeployment|%{environmentsCount} of %{totalEnvironmentsCount} environments',
    ),
    searchPlaceholder: s__('ContinuousDeployment|Filter environments...'),
    filterEmptyStateTitle: s__('ContinuousDeployment|No environments match your filters'),
    filterEmptyStateDescription: __('To widen your search, change or remove filters above.'),
    clearFilters: s__('ContinuousDeployment|Clear filters'),
  },
  data() {
    return {
      environmentsConnection: null,
      selectedFilterId: STATUS_ALL,
      searchTerm: '',
      isPanelOpen: false,
      isInitialLoad: true,
      isLoadingMore: false,
    };
  },
  apollo: {
    environmentsConnection: {
      query: cdEnvironmentsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.organization?.cdEnvironments ?? null;
      },
      // The initial page load owns the page-level loader. Every load after it
      // comes from a tier filter or a search, which loads the list on its own.
      watchLoading(isLoading) {
        if (!isLoading) {
          this.isInitialLoad = false;
        }
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    statusFilters() {
      return Object.entries(ENVIRONMENT_FILTERS).map(([id, text]) => ({ id, text }));
    },
    tierFilter() {
      // CdEnvironmentTier has no "all" member, so showing all types means
      // sending no tier at all.
      return this.selectedFilterId === STATUS_ALL ? null : this.selectedFilterId;
    },
    queryVariables() {
      return {
        search: this.searchTerm.trim(),
        tier: this.tierFilter,
        first: ENVIRONMENTS_PAGE_SIZE,
      };
    },
    environments() {
      return this.environmentsConnection?.nodes || [];
    },
    pageInfo() {
      return this.environmentsConnection?.pageInfo || {};
    },
    hasNextPage() {
      return Boolean(this.pageInfo.hasNextPage);
    },
    isLoading() {
      return this.$apollo.queries.environmentsConnection.loading;
    },
    isPageLoading() {
      return this.isInitialLoad;
    },
    isListLoading() {
      // Loading another page keeps the already loaded environments on screen,
      // so only the button it comes from shows a loading state.
      return !this.isInitialLoad && this.isLoading && !this.isLoadingMore;
    },
    hasFilters() {
      return Boolean(this.searchTerm.trim()) || this.selectedFilterId !== STATUS_ALL;
    },
    showFilterEmptyState() {
      return !this.isListLoading && this.hasFilters && !this.environments.length;
    },
    environmentsCount() {
      return '0';
    },
    totalEnvironmentsCount() {
      return '0';
    },
  },
  methods: {
    onFilterSelected(id) {
      this.selectedFilterId = id;
    },
    onSearch(term) {
      this.searchTerm = term;
    },
    clearFilters() {
      this.selectedFilterId = STATUS_ALL;
      this.searchTerm = '';
    },
    async loadMore() {
      if (this.isLoadingMore || !this.hasNextPage) {
        return;
      }

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.environmentsConnection.fetchMore({
          variables: { ...this.queryVariables, after: this.pageInfo.endCursor },
          updateQuery(previousResult, { fetchMoreResult }) {
            const previousNodes = previousResult.organization.cdEnvironments.nodes;

            return produce(fetchMoreResult, (draftState) => {
              draftState.organization.cdEnvironments.nodes = [
                ...previousNodes,
                ...fetchMoreResult.organization.cdEnvironments.nodes,
              ];
            });
          },
        });
      } catch (error) {
        Sentry.captureException(error);
      } finally {
        this.isLoadingMore = false;
      }
    },
    openPanel() {
      this.isPanelOpen = true;
    },
    closePanel() {
      this.isPanelOpen = false;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="$options.i18n.title">
      <template #actions>
        <gl-button variant="confirm" data-testid="register-environment-button" @click="openPanel">
          {{ $options.i18n.registerEnvironment }}
        </gl-button>
      </template>
      <template #description>
        <gl-sprintf :message="$options.i18n.environmentsCountLabel">
          <template #environmentsCount>
            {{ environmentsCount }}
          </template>
          <template #totalEnvironmentsCount>
            {{ totalEnvironmentsCount }}
          </template>
        </gl-sprintf>
      </template>
    </page-heading>
    <filter-bar
      :filters="statusFilters"
      :selected-filter-id="selectedFilterId"
      :search-term="searchTerm"
      :search-placeholder="$options.i18n.searchPlaceholder"
      @filter-selected="onFilterSelected"
      @search="onSearch"
    />
    <gl-loading-icon v-if="isPageLoading" size="lg" class="gl-mt-5" data-testid="page-loader" />
    <gl-empty-state
      v-else-if="showFilterEmptyState"
      illustration-name="empty-search-md"
      :title="$options.i18n.filterEmptyStateTitle"
      :description="$options.i18n.filterEmptyStateDescription"
    >
      <template #actions>
        <gl-button variant="confirm" data-testid="clear-filters-button" @click="clearFilters">
          {{ $options.i18n.clearFilters }}
        </gl-button>
      </template>
    </gl-empty-state>
    <environment-list
      v-else
      :environments="environments"
      :loading="isListLoading"
      :has-next-page="hasNextPage"
      :loading-more="isLoadingMore"
      @register="openPanel"
      @load-more="loadMore"
    />
    <new-environment-panel
      :open="isPanelOpen"
      :query-variables="queryVariables"
      @close="closePanel"
    />
  </div>
</template>
