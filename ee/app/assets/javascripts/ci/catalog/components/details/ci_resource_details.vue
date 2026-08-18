<script>
import { GlTab, GlAlert, GlLoadingIcon, GlEmptyState } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-catalog-md.svg';
import { getParameterByName } from '~/lib/utils/url_utility';
import CeCiResourceDetails from '~/ci/catalog/components/details/ci_resource_details.vue';
import { InternalEvents } from '~/tracking';
import getCatalogResourceUsage from '../../graphql/queries/get_resource_usage.query.graphql';
import getCatalogResourceUsagePermissions from '../../graphql/queries/get_resource_usage_permissions.query.graphql';
import { DEFAULT_USAGE_SORT } from '../../constants';
import UsageDetails from './usage_details.vue';

const ITEMS_PER_PAGE = 20;
const TAB_NAME_USAGE = 'usage';

export default {
  name: 'CiResourceDetailsEE',
  components: {
    CeCiResourceDetails,
    GlTab,
    GlAlert,
    GlLoadingIcon,
    GlEmptyState,
    UsageDetails,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    resourcePath: {
      type: String,
      required: true,
    },
    version: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      componentUsages: [],
      pageInfo: {},
      paginationParams: { first: ITEMS_PER_PAGE },
      hasError: false,
      isFeatureAvailable: false,
      selectedVersionIds: [],
      componentNameFilter: null,
      sortOrder: DEFAULT_USAGE_SORT,
    };
  },
  apollo: {
    isFeatureAvailable: {
      query: getCatalogResourceUsagePermissions,
      variables() {
        return {
          fullPath: this.resourcePath,
        };
      },
      update(data) {
        const userPermissions = data?.project?.userPermissions?.readProjectComponentUsages ?? false;
        const featureAvailable = data?.project?.licensedFeatureAvailability?.available ?? false;
        return userPermissions && featureAvailable;
      },
    },
    componentUsages: {
      query: getCatalogResourceUsage,
      variables() {
        return {
          fullPath: this.resourcePath,
          versionIds: this.selectedVersionIds.length > 0 ? this.selectedVersionIds : null,
          componentName: this.componentNameFilter,
          sort: this.sortOrder,
          ...this.paginationParams,
        };
      },
      update(data) {
        return data?.ciCatalogResource?.projectComponentUsages?.nodes || [];
      },
      result({ data }) {
        this.pageInfo = data?.ciCatalogResource?.projectComponentUsages?.pageInfo || {};
      },
      skip() {
        return !this.isFeatureAvailable;
      },
      error() {
        this.hasError = true;
      },
    },
  },
  computed: {
    isWaitingForPermissionsCheck() {
      return this.$apollo.queries.isFeatureAvailable.loading && this.isUsageTab;
    },
    isUsageTab() {
      return getParameterByName('tab') === TAB_NAME_USAGE;
    },
    isLoading() {
      return this.$apollo.queries.componentUsages.loading;
    },
    isInitialLoading() {
      return this.isLoading && !this.hasActiveFilter && this.componentUsages.length === 0;
    },
    hasActiveFilter() {
      return this.selectedVersionIds.length > 0 || this.componentNameFilter !== null;
    },
    showEmptyState() {
      return !this.componentUsages.length && !this.hasActiveFilter && !this.isLoading;
    },
  },
  methods: {
    handleNextPage() {
      this.paginationParams = { first: ITEMS_PER_PAGE, after: this.pageInfo.endCursor };
    },
    handlePrevPage() {
      this.paginationParams = { last: ITEMS_PER_PAGE, before: this.pageInfo.startCursor };
    },
    handleFiltersChanged({ componentName, versionIds }) {
      this.componentNameFilter = componentName;
      this.selectedVersionIds = versionIds;
      this.paginationParams = { first: ITEMS_PER_PAGE };
    },
    handleSort(sortOrder) {
      this.sortOrder = sortOrder;
      this.paginationParams = { first: ITEMS_PER_PAGE };
    },
    onUsageTabClick() {
      this.trackEvent('click_component_usage_tab_on_ci_catalog');
    },
  },
  EMPTY_SVG_URL,
  TAB_NAME_USAGE,
};
</script>

<template>
  <gl-loading-icon v-if="isWaitingForPermissionsCheck" size="lg" />
  <ce-ci-resource-details v-else :resource-path="resourcePath" :version="version">
    <template v-if="isFeatureAvailable" #extra-tabs>
      <gl-tab
        :title="s__('CiCatalog|Usage')"
        :query-param-value="$options.TAB_NAME_USAGE"
        lazy
        @click="onUsageTabClick"
      >
        <gl-alert v-if="hasError" variant="danger" @dismiss="hasError = false">{{
          s__(
            'CiCatalog|An error occurred while fetching usage statistics. Refresh the page or try again later.',
          )
        }}</gl-alert>
        <gl-loading-icon v-if="isInitialLoading" size="lg" />
        <gl-empty-state
          v-else-if="showEmptyState"
          :title="s__('CiCatalog|No usage data available')"
          :description="
            s__(
              'CiCatalog|There are no projects using this resource in the last 30 days, or you don\'t have permission to view them.',
            )
          "
          :svg-path="$options.EMPTY_SVG_URL"
        />
        <usage-details
          v-else
          :component-usages="componentUsages"
          :page-info="pageInfo"
          :resource-path="resourcePath"
          :is-loading="isLoading"
          @next-page="handleNextPage"
          @prev-page="handlePrevPage"
          @filters-changed="handleFiltersChanged"
          @sort="handleSort"
        />
      </gl-tab>
    </template>
  </ce-ci-resource-details>
</template>
