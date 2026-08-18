<script>
import { nextTick } from 'vue';
import { GlAlert, GlLink, GlSprintf, GlLoadingIcon, GlKeysetPagination } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';

import { GRAPHQL_PAGE_SIZE, GRAPHQL_FIELD_MISSING_ERROR_MESSAGE } from '../../constants';
import { isGraphqlFieldMissingError } from '../../utils';

import DetailsDrawer from './components/details_drawer/details_drawer.vue';
import GroupedTable from './components/grouped_table/grouped_table.vue';
import FiltersBar from './components/filters_bar/filters_bar.vue';
import { GroupedLoader } from './services/grouped_loader';

const GROUP_PAGE_LIMIT = 20;

export default {
  name: 'ComplianceStandardsAdherenceTableV2',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    GlLoadingIcon,
    GlKeysetPagination,

    FiltersBar,
    DetailsDrawer,
    PageSizeSelector,
    GroupedTable,
  },
  props: {
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      selectedStatus: null,
      items: {
        data: [],
        pageInfo: {},
      },
      isInitiallyLoading: true,
      isLoading: true,
      perPage: GRAPHQL_PAGE_SIZE,
      filters: {},
      groupBy: null,

      errorMessage: null,
    };
  },
  computed: {
    hasItems() {
      return this.items.data.some((item) => item.children.length > 0);
    },
    filtersAndGroupBy() {
      return { ...this.filters, groupBy: this.groupBy };
    },
  },
  watch: {
    filters(newFilters) {
      this.groupedLoader.setFilters(newFilters);
    },
    groupBy(newGroupBy) {
      this.perPage = GROUP_PAGE_LIMIT;
      this.groupedLoader.setGroupBy(newGroupBy);
      this.items = {
        data: [],
        pageInfo: {},
      };
    },
    filtersAndGroupBy() {
      this.loadFirstPage();
    },
  },
  mounted() {
    const mode = this.projectPath ? 'project' : 'group';
    this.groupedLoader = new GroupedLoader({
      mode,
      fullPath: this.projectPath || this.groupPath,
      apollo: this.$apollo,
    });
    this.loadFirstPage();
  },
  methods: {
    onRowSelected(item) {
      if (this.selectedStatus === item) {
        return;
      }

      this.selectedStatus = null;
      nextTick(() => {
        this.selectedStatus = item;
      });
    },

    async invokeLoader(loaderMethod = 'loadPage') {
      try {
        this.errorMessage = null;
        this.isLoading = true;
        this.items = await this.groupedLoader[loaderMethod]();
      } catch (error) {
        if (isGraphqlFieldMissingError(error, 'projectComplianceRequirementsStatus')) {
          this.errorMessage = GRAPHQL_FIELD_MISSING_ERROR_MESSAGE;
        } else {
          this.errorMessage = this.$options.i18n.errorMessage;
        }
      } finally {
        this.isInitiallyLoading = false;
        this.isLoading = false;
      }
    },

    loadFirstPage() {
      this.invokeLoader();
    },
    onPageSizeChange(perPage) {
      this.perPage = perPage;
      this.groupedLoader.setPageSize(perPage);
      this.loadFirstPage();
    },
    loadPrevPage() {
      this.invokeLoader('loadPrevPage');
    },
    loadNextPage() {
      this.invokeLoader('loadNextPage');
    },
  },
  i18n: {
    errorMessage: s__('AdherenceReport|There was an error loading adherence report.'),
    emptyReport: s__('AdherenceReport|No statuses found.'),
    emptyReportHelp: s__(
      'AdherenceReport|To show a status here, you must %{linkStart}create a compliance framework with requirements and controls%{linkEnd} and apply it to projects in this group. New frameworks can take a few minutes to appear.',
    ),
  },
};
</script>

<template>
  <section>
    <details-drawer :status="selectedStatus" @close="selectedStatus = null" />
    <gl-alert v-if="errorMessage" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>
    <filters-bar
      :group-path="groupPath"
      :filters.sync="filters"
      :group-by.sync="groupBy"
      :with-projects="!projectPath"
      with-group-by
      @load="isInitiallyLoading = false"
    />
    <template v-if="isInitiallyLoading">
      <gl-loading-icon size="lg" class="gl-mt-5" />
    </template>
    <div v-else>
      <gl-loading-icon v-if="isLoading" size="md" class="gl-m-5" />
      <template v-else-if="hasItems">
        <grouped-table :items="items.data" :group-by="groupBy" @row-selected="onRowSelected" />
        <div v-if="items.pageInfo" class="gl-justify-between @md/panel:gl-flex">
          <div class="gl-hidden gl-grow gl-basis-0 @md/panel:gl-flex"></div>
          <div class="gl-float-left@md/panel:gl-flex gl-grow gl-basis-0 gl-justify-center">
            <gl-keyset-pagination
              v-bind="items.pageInfo"
              :disabled="isLoading"
              @prev="loadPrevPage"
              @next="loadNextPage"
            />
          </div>
          <div
            v-if="!groupBy"
            class="gl-float-right gl-grow gl-basis-0 gl-justify-end @md/panel:gl-flex"
          >
            <page-size-selector :value="perPage" @input="onPageSizeChange" />
          </div>
        </div>
      </template>
      <template v-else>
        <div class="gl-my-5 gl-text-center">
          {{ $options.i18n.emptyReport }}
        </div>
        <div class="gl-my-5 gl-text-center">
          <gl-sprintf :message="$options.i18n.emptyReportHelp">
            <template #link="{ content }">
              <gl-link
                href="/user/compliance/compliance_frameworks/_index"
                anchor="requirements"
                target="_blank"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </div>
      </template>
    </div>
  </section>
</template>
