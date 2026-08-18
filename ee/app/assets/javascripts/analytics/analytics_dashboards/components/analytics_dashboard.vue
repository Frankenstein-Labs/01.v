<script>
import { defineAsyncComponent } from 'vue';
import {
  GlEmptyState,
  GlSkeletonLoader,
  GlAlert,
  GlLink,
  GlSprintf,
  GlDashboardLayout,
  GlExperimentBadge,
} from '@gitlab/ui';
import { createAlert, VARIANT_WARNING, VARIANT_DANGER } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import {
  GRID_HEIGHT_COMPACT,
  GRID_HEIGHT_COMPACT_CELL_HEIGHT,
  GRID_HEIGHT_COMPACT_MIN_CELL_HEIGHT,
} from '~/explore/analytics_dashboards/constants';
import { getUniquePanelId } from '~/explore/analytics_dashboards/utils';
import UsageOverviewBackgroundAggregationWarning from 'ee/analytics/dashboards/components/usage_overview_background_aggregation_warning.vue';
import UrlSync, {
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
} from '~/vue_shared/components/url_sync.vue';
import { setPageFullWidth, setPageDefaultWidth } from '~/lib/utils/common_utils';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';
import {
  AI_IMPACT_DASHBOARD,
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  EVENT_LABEL_VIEWED_DASHBOARD,
  DEFAULT_DASHBOARD_LOADING_ERROR,
  DASHBOARD_REFRESH_MESSAGE,
} from '../constants';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import {
  buildDefaultDashboardFilters,
  filtersToQueryParams,
  isDashboardFilterEnabled,
} from './filters/utils';

export default {
  name: 'AnalyticsDashboard',
  components: {
    DateRangeFilter: defineAsyncComponent(
      () => import('~/explore/analytics_dashboards/components/date_range_filter.vue'),
    ),
    AnonUsersFilter: defineAsyncComponent(() => import('./filters/anon_users_filter.vue')),
    ProjectsFilter: defineAsyncComponent(
      () => import('~/explore/analytics_dashboards/components/projects_filter.vue'),
    ),
    FilteredSearchFilter: defineAsyncComponent(
      () => import('./filters/filtered_search_filter.vue'),
    ),
    AnalyticsDashboardPanel,
    GlEmptyState,
    GlSkeletonLoader,
    GlAlert,
    UsageOverviewBackgroundAggregationWarning,
    GlLink,
    GlSprintf,
    UrlSync,
    GlDashboardLayout,
    GlExperimentBadge,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    namespaceFullPath: {
      type: String,
    },
    dashboardEmptyStateIllustrationPath: {
      type: String,
    },
    breadcrumbState: {
      type: Object,
    },
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  data() {
    return {
      dashboard: null,
      showEmptyState: false,
      filters: null,
      backUrl: this.$router.resolve('/').href,
      alert: null,
      hasDashboardLoadError: false,
    };
  },
  computed: {
    showFilters() {
      return [
        this.showProjectsFilter,
        this.showAnonUserFilter,
        this.showDateRangeFilter,
        this.showFilteredSearchFilter,
      ].some(Boolean);
    },
    showDateRangeFilter() {
      return isDashboardFilterEnabled(this.dateRangeFilter);
    },
    showProjectsFilter() {
      return isDashboardFilterEnabled(this.dashboard?.filters?.projects);
    },
    dateRangeFilter() {
      return this.dashboard?.filters?.dateRange || {};
    },
    dateRangeLimit() {
      return this.dateRangeFilter.numberOfDaysLimit || 0;
    },
    cellHeight() {
      return this.dashboard?.gridHeight === GRID_HEIGHT_COMPACT
        ? GRID_HEIGHT_COMPACT_CELL_HEIGHT
        : undefined;
    },
    minCellHeight() {
      return this.dashboard?.gridHeight === GRID_HEIGHT_COMPACT
        ? GRID_HEIGHT_COMPACT_MIN_CELL_HEIGHT
        : undefined;
    },
    showAnonUserFilter() {
      return isDashboardFilterEnabled(this.dashboard?.filters?.excludeAnonymousUsers);
    },
    filteredSearchFilter() {
      return this.dashboard?.filters?.filteredSearch;
    },
    showFilteredSearchFilter() {
      return isDashboardFilterEnabled(this.filteredSearchFilter);
    },
    invalidDashboardErrors() {
      return this.dashboard?.errors ?? [];
    },
    hasDashboardError() {
      return this.hasDashboardLoadError || this.invalidDashboardErrors.length > 0;
    },
    dashboardHasUsageOverviewPanel() {
      return this.dashboard?.panels.some(({ visualization }) =>
        ['usage_overview', 'usage_count'].includes(visualization?.data?.type),
      );
    },
    showEnableAggregationWarning() {
      return this.dashboardHasUsageOverviewPanel && !this.overviewCountsAggregationEnabled;
    },
    hasCustomDescriptionLink() {
      return this.isValueStreamsDashboard || this.isAiImpactDashboard;
    },
    isValueStreamsDashboard() {
      return this.dashboard.slug === BUILT_IN_VALUE_STREAM_DASHBOARD;
    },
    isAiImpactDashboard() {
      return this.dashboard.slug === AI_IMPACT_DASHBOARD;
    },
    queryParams() {
      return filtersToQueryParams(this.filters);
    },
    dateRangeOptions() {
      return this.dashboard.filters?.dateRange?.options;
    },
    filteredSearchOptions() {
      return this.dashboard.filters?.filteredSearch?.options;
    },
    filteredProjectsMultiSelect() {
      return Boolean(this.dashboard.filters?.projects?.multiSelect);
    },
    statusBadgeType() {
      return this.dashboard?.status || null;
    },
    hasStatusBadge() {
      return Boolean(!this.dashboard.userDefined && this.statusBadgeType);
    },
  },
  watch: {
    dashboard({ title: label, userDefined } = {}) {
      this.trackEvent(EVENT_LABEL_VIEWED_DASHBOARD, {
        label,
      });

      this.filters = buildDefaultDashboardFilters(window.location.search, this.dashboard.filters);

      if (userDefined) {
        this.trackEvent(EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD, {
          label,
        });
      } else {
        this.trackEvent(EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD, {
          label,
        });
      }
    },
  },
  mounted() {
    setPageFullWidth();
  },
  beforeDestroy() {
    setPageDefaultWidth();

    this.alert?.dismiss();

    // Clear the breadcrumb name when we leave this component so it doesn't
    // flash the wrong name when a user views a different dashboard
    this.breadcrumbState.updateName('');
  },
  apollo: {
    dashboard: {
      query: getCustomizableDashboardQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          slug: this.$route?.params.slug,
        };
      },
      update(data) {
        const namespaceData = data.project ? data.project : data.group;
        const [dashboard] = namespaceData?.customizableDashboards?.nodes || [];

        if (!dashboard) {
          this.showEmptyState = true;
          return null;
        }

        return {
          ...dashboard,
          panels: this.getDashboardPanels(dashboard),
        };
      },
      result() {
        this.breadcrumbState.updateName(this.dashboard?.title || '');

        this.validateFilters(this.dashboard?.filters);
      },
      error(error) {
        const message = [
          error.message || DEFAULT_DASHBOARD_LOADING_ERROR,
          DASHBOARD_REFRESH_MESSAGE,
        ].join('. ');

        this.showError({
          error,
          capture: true,
          title: s__('Analytics|Failed to load dashboard'),
          message,
          messageLinks: {
            link: this.$options.troubleshootingUrl,
          },
        });
        this.hasDashboardLoadError = true;
      },
    },
  },
  methods: {
    getDashboardPanels(dashboard) {
      const panels = dashboard.panels?.nodes || [];

      return panels.map(({ id, ...panel }) => ({
        ...panel,
        id: getUniquePanelId(),
      }));
    },
    showError({ error, capture, message, messageLinks, title = '', variant = VARIANT_DANGER }) {
      this.alert = createAlert({
        variant,
        title,
        message,
        messageLinks,
        error,
        captureError: capture,
      });
    },
    validateFilters(filters = {}) {
      if (filters?.dateRange?.enabled && filters?.dateRange.defaultOption) {
        const {
          dateRange: { defaultOption, options = [] },
        } = filters;
        if (!options.includes(defaultOption)) {
          this.showError({
            title: this.$options.i18n.dateRangeFilterValidationTitle,
            variant: VARIANT_WARNING,
            message: sprintf(this.$options.i18n.dateRangeFilterValidationMessage, {
              defaultOption,
            }),
          });
        }
      }
    },
    panelTestId({ visualization: { slug = '' } }) {
      return `panel-${slug.replaceAll('_', '-')}`;
    },
    setDateRangeFilter({ dateRangeOption, startDate, endDate }) {
      this.filters = {
        ...this.filters,
        dateRangeOption,
        startDate,
        endDate,
      };
    },
    setAnonymousUsersFilter(filterAnonUsers) {
      this.filters = {
        ...this.filters,
        filterAnonUsers,
      };

      if (filterAnonUsers) {
        this.trackEvent(EVENT_LABEL_EXCLUDE_ANONYMISED_USERS);
      }
    },
    setProjectsFilter(projects) {
      this.filters = {
        ...this.filters,
        projects: projects?.map(({ fullPath }) => fullPath) || [],
      };
    },
    setFilteredSearchFilter(searchFilters) {
      this.filters = {
        ...this.filters,
        searchFilters,
      };
    },
  },
  troubleshootingUrl: helpPagePath('user/analytics/analytics_dashboards'),
  i18n: {
    aiImpactDescriptionLink: s__(
      'Analytics|Learn more about %{docsLinkStart}Duo and SDLC trends%{docsLinkEnd} and %{subscriptionLinkStart}Duo seats%{subscriptionLinkEnd}.',
    ),
    dateRangeFilterValidationTitle: __('Date range filter validation'),
    dateRangeFilterValidationMessage: s__(
      "Analytics|Default date range '%{defaultOption}' is not included in the list of dateRange options",
    ),
  },
  VSD_DOCUMENTATION_LINK: helpPagePath('user/analytics/value_streams_dashboard'),
  AI_IMPACT_DOCUMENTATION_LINK: helpPagePath('user/analytics/duo_and_sdlc_trends'),
  DUO_PRO_SUBSCRIPTION_ADD_ON_LINK: helpPagePath('subscriptions/subscription-add-ons'),
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
};
</script>

<template>
  <div>
    <template v-if="dashboard">
      <gl-alert
        v-if="invalidDashboardErrors.length > 0"
        data-testid="analytics-dashboard-invalid-config-alert"
        class="gl-mt-4"
        :title="s__('Analytics|Invalid dashboard configuration')"
        :primary-button-text="__('Learn more')"
        :primary-button-link="$options.troubleshootingUrl"
        :dismissible="false"
        variant="danger"
      >
        <ul class="gl-m-0">
          <li v-for="errorMessage in invalidDashboardErrors" :key="errorMessage">
            {{ errorMessage }}
          </li>
        </ul>
      </gl-alert>

      <gl-dashboard-layout
        :config="dashboard"
        :cell-height="cellHeight"
        :min-cell-height="minCellHeight"
        data-testid="analytics-dashboard"
      >
        <template v-if="hasStatusBadge" #title>
          <h2 data-testid="custom-title" class="gl-my-0">{{ dashboard.title }}</h2>
          <gl-experiment-badge class="gl-ml-3" :type="statusBadgeType" />
        </template>

        <!-- TODO: Remove this link in https://gitlab.com/gitlab-org/gitlab/-/issues/465569 -->
        <template v-if="hasCustomDescriptionLink" #description>
          <p class="gl-mb-0" data-testid="custom-description">
            {{ dashboard.description }}
            <span data-testid="custom-description-link">
              <gl-sprintf
                v-if="isAiImpactDashboard"
                :message="$options.i18n.aiImpactDescriptionLink"
              >
                <template #docsLink="{ content }">
                  <gl-link :href="$options.AI_IMPACT_DOCUMENTATION_LINK">{{ content }}</gl-link>
                </template>
                <template #subscriptionLink="{ content }">
                  <gl-link :href="$options.DUO_PRO_SUBSCRIPTION_ADD_ON_LINK">{{ content }}</gl-link>
                </template>
              </gl-sprintf>

              <gl-sprintf
                v-else-if="isValueStreamsDashboard"
                :message="__('%{linkStart} Learn more%{linkEnd}.')"
              >
                <template #link="{ content }">
                  <gl-link :href="$options.VSD_DOCUMENTATION_LINK">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </span>
          </p>
        </template>

        <template v-if="showEnableAggregationWarning" #alert>
          <usage-overview-background-aggregation-warning />
        </template>

        <template v-if="showFilters" #filters>
          <filtered-search-filter
            v-if="showFilteredSearchFilter"
            class="gl-basis-full"
            :initial-filter-value="filters.searchFilters"
            :options="filteredSearchOptions"
            @change="setFilteredSearchFilter"
          />
          <projects-filter
            v-if="showProjectsFilter"
            :group-namespace="namespaceFullPath"
            :multi-select="filteredProjectsMultiSelect"
            @project-selected="setProjectsFilter"
          />
          <date-range-filter
            v-if="showDateRangeFilter"
            :default-option="filters.dateRangeOption"
            :start-date="filters.startDate"
            :end-date="filters.endDate"
            :date-range-limit="dateRangeLimit"
            :options="dateRangeOptions"
            @change="setDateRangeFilter"
          />
          <anon-users-filter
            v-if="showAnonUserFilter"
            :value="filters.filterAnonUsers"
            @change="setAnonymousUsersFilter"
          />
          <url-sync
            :query="queryParams"
            :url-params-update-strategy="$options.URL_SET_PARAMS_STRATEGY"
            :history-update-method="$options.HISTORY_REPLACE_UPDATE_METHOD"
          />
        </template>

        <template #panel="{ panel }">
          <analytics-dashboard-panel
            :title="panel.title"
            :title-icon="panel.titleIcon || ''"
            :tooltip="panel.tooltip"
            :visualization="panel.visualization"
            :views="panel.views"
            :query-overrides="panel.queryOverrides || undefined"
            :filters="filters"
            :data-testid="panelTestId(panel)"
          />
        </template>
      </gl-dashboard-layout>
    </template>
    <gl-empty-state
      v-else-if="showEmptyState"
      :svg-path="dashboardEmptyStateIllustrationPath"
      :title="s__('Analytics|Dashboard not found')"
      :description="s__('Analytics|No dashboard matches the specified URL path.')"
      :primary-button-text="s__('Analytics|View available dashboards')"
      :primary-button-link="backUrl"
    />
    <div v-else-if="!hasDashboardError" class="gl-mt-7">
      <gl-skeleton-loader />
    </div>
  </div>
</template>
