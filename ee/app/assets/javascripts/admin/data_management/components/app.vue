<script>
import { computed } from 'vue';
import { GlKeysetPagination } from '@gitlab/ui';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import {
  BULK_ACTIONS,
  DEFAULT_SORT,
  GEO_TROUBLESHOOTING_LINK,
} from 'ee/admin/data_management/constants';
import { extractFiltersFromQuery, processFilters } from 'ee/admin/data_management/filters';
import { createAlert } from '~/alert';
import { getModels, putBulkModelAction } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import showToast from '~/vue_shared/plugins/global_toast';

export default {
  name: 'AdminDataManagementApp',
  components: {
    GeoListTopBar,
    GeoList,
    GlKeysetPagination,
    DataManagementItem,
  },
  provide() {
    return {
      itemTitle: computed(() => this.modelTypeTitle),
    };
  },
  props: {
    initialModelTypeName: {
      type: String,
      required: true,
    },
    modelTypes: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      modelItems: [],
      filters: [],
      pageInfo: {},
      isLoading: true,
    };
  },
  computed: {
    activeModelType() {
      const activeModelTypeName = this.routerParams.modelName || this.initialModelTypeName;

      return this.modelTypes.find(({ namePlural }) => namePlural === activeModelTypeName);
    },
    modelTypeTitle() {
      return this.activeModelType.titlePlural.toLowerCase();
    },
    hasItems() {
      return Boolean(this.modelItems.length);
    },
    hasFilters() {
      return Boolean(this.filters.length);
    },
    hasNextPage() {
      return Boolean(this.pageInfo.nextCursor);
    },
    hasPrevPage() {
      return Boolean(this.pageInfo.prevCursor);
    },
    bulkActions() {
      if (!this.activeModelType.checksumEnabled) {
        return [];
      }

      return BULK_ACTIONS;
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|No %{itemTitle} exist'), {
          itemTitle: this.modelTypeTitle,
        }),
        description: s__(
          'Geo|If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        ),
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.hasFilters,
      };
    },
    routerParams() {
      const { query, params } = this.$route;
      return convertObjectPropsToCamelCase({ ...query, ...params });
    },
    query() {
      const filterQuery = processFilters(this.filters);
      return {
        ...filterQuery,
        order_by: this.pageInfo.sort.value,
        sort: this.pageInfo.sort.direction,
      };
    },
    queryWithPagination() {
      return { ...this.query, pagination: 'keyset', cursor: this.pageInfo.currentCursor };
    },
  },
  watch: {
    $route: {
      handler() {
        this.initializePageInfo();
        this.initializeFilters();
        this.fetchModelList();
      },
      immediate: true,
    },
  },
  methods: {
    initializePageInfo() {
      this.pageInfo = {
        currentCursor: this.routerParams.cursor,
        sort: {
          value: this.routerParams.orderBy || DEFAULT_SORT.value,
          direction: this.routerParams.sort || DEFAULT_SORT.direction,
        },
      };
    },
    initializeFilters() {
      this.filters = extractFiltersFromQuery(this.routerParams);
    },
    updateCursor(headers) {
      this.pageInfo = {
        ...this.pageInfo,
        prevCursor: headers['x-prev-cursor'],
        nextCursor: headers['x-next-cursor'],
      };
    },
    async fetchModelList() {
      this.isLoading = true;

      try {
        const { data, headers } = await getModels(
          this.activeModelType.namePlural,
          this.queryWithPagination,
        );

        this.modelItems = convertObjectPropsToCamelCase(data, { deep: true });
        this.updateCursor(headers);
      } catch (error) {
        this.handleFetchError(error);
      } finally {
        this.isLoading = false;
      }
    },
    async handleBulkAction({ action, successMessage, errorMessage }) {
      try {
        await putBulkModelAction(this.activeModelType.namePlural, action);

        showToast(sprintf(successMessage, { type: this.modelTypeTitle }));
        this.fetchModelList();
      } catch (error) {
        createAlert({
          message: sprintf(errorMessage, { type: this.modelTypeTitle }),
          captureError: true,
          error,
        });
      }
    },
    handleFetchError(error) {
      createAlert({
        message: sprintf(
          s__(
            'Geo|There was an error fetching %{modelType}. Please refresh the page and try again.',
          ),
          { modelType: this.modelTypeTitle },
        ),
        captureError: true,
        error,
      });
    },
    handleListboxChange(modelName) {
      const params = { modelName };
      this.$router.push({ params, query: this.query });
    },
    handleSearch(filters) {
      this.filters = filters;
      this.$router.push({ params: this.$route.params, query: this.query });
    },
    handleSort(sort) {
      this.pageInfo = { ...this.pageInfo, sort };
      this.$router.push({ params: this.$route.params, query: this.query });
    },
    handleNextPage() {
      this.pageInfo.currentCursor = this.pageInfo.nextCursor;
      this.$router.push({ params: this.$route.params, query: this.queryWithPagination });
    },
    handlePrevPage() {
      this.pageInfo.currentCursor = this.pageInfo.prevCursor;
      this.$router.push({ params: this.$route.params, query: this.queryWithPagination });
    },
  },
};
</script>

<template>
  <section>
    <geo-list-top-bar
      :active-filtered-search-filters="filters"
      :page-heading-title="__('Data management')"
      :page-heading-description="
        s__('Geo|Review stored data and data health within your instance.')
      "
      :filtered-search-option-label="__('Search by ID')"
      :active-listbox-item="activeModelType.namePlural"
      :active-sort="pageInfo.sort"
      :bulk-actions="bulkActions"
      :show-actions="hasItems"
      @listbox-change="handleListboxChange"
      @search="handleSearch"
      @sort="handleSort"
      @bulk-action="handleBulkAction"
    />
    <geo-list :is-loading="isLoading" :has-items="hasItems" :empty-state="emptyState">
      <data-management-item
        v-for="item in modelItems"
        :key="item.recordIdentifier"
        :active-model-type="activeModelType"
        :initial-item="item"
      />
    </geo-list>
    <div class="gl-mt-6 gl-flex gl-justify-center">
      <gl-keyset-pagination
        :disabled="isLoading"
        :has-next-page="hasNextPage"
        :has-previous-page="hasPrevPage"
        @next="handleNextPage"
        @prev="handlePrevPage"
      />
    </div>
  </section>
</template>
