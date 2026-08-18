<script>
import { GlAlert, GlTable, GlIcon, GlLink, GlLoadingIcon } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import InternalEvents from '~/tracking/internal_events';
import getProjectComplianceStandardsGroupAdherence from 'ee/compliance_dashboard/graphql/compliance_standards_group_adherence.query.graphql';
import getProjectComplianceStandardsProjectAdherence from 'ee/compliance_dashboard/graphql/compliance_standards_project_adherence.query.graphql';
import FrameworksInfo from '../shared/frameworks_info.vue';
import Pagination from '../shared/pagination.vue';
import { GRAPHQL_PAGE_SIZE, GRAPHQL_FIELD_MISSING_ERROR_MESSAGE } from '../../constants';
import { isTopLevelGroup, isGraphqlFieldMissingError } from '../../utils';
import {
  FAIL_STATUS,
  STANDARDS_ADHERENCE_CHECK_LABELS,
  STANDARDS_ADHERENCE_STANARD_LABELS,
  NO_STANDARDS_ADHERENCES_FOUND,
  STANDARDS_ADHERENCE_FETCH_ERROR,
} from './constants';
import FixSuggestionsSidebar from './fix_suggestions_sidebar.vue';

export default {
  name: 'AdherencesBaseTable',
  components: {
    GlAlert,
    GlTable,
    GlIcon,
    GlLink,
    GlLoadingIcon,
    FixSuggestionsSidebar,
    Pagination,
    FrameworksInfo,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['rootAncestorPath'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: String,
      required: false,
      default: '',
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    standard: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      hasStandardsAdherenceFetchError: false,
      customErrorText: null,
      drawerId: null,
      drawerAdherence: {},
      adherences: {
        list: [],
        pageInfo: {},
      },
    };
  },
  apollo: {
    adherences: {
      query() {
        return this.projectPath
          ? getProjectComplianceStandardsProjectAdherence
          : getProjectComplianceStandardsGroupAdherence;
      },
      variables() {
        return {
          fullPath: this.projectPath ?? this.groupPath,
          filters: { ...this.filters, ...this.queryFilters },
          ...this.paginationCursors,
        };
      },
      update(data) {
        const { nodes, pageInfo } = data?.container?.projectComplianceStandardsAdherence || {};
        return {
          list: nodes,
          pageInfo,
        };
      },
      error(e) {
        Sentry.captureException(e);
        this.hasStandardsAdherenceFetchError = true;
        this.customErrorText = isGraphqlFieldMissingError(e, 'projectComplianceStandardsAdherence')
          ? GRAPHQL_FIELD_MISSING_ERROR_MESSAGE
          : null;
      },
    },
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestorPath);
    },
    isLoading() {
      return Boolean(this.$apollo.queries.adherences.loading);
    },
    queryFilters() {
      if (this.check) {
        return { checkName: this.check };
      }

      if (this.standard) {
        return { standard: this.standard };
      }

      return {};
    },
    showDrawer() {
      return this.drawerId !== null;
    },
    showPagination() {
      const { hasPreviousPage, hasNextPage } = this.adherences.pageInfo || {};
      return hasPreviousPage || hasNextPage;
    },
    paginationCursors() {
      const { before, after } = this.$route.query;

      if (before) {
        return {
          before,
          last: this.perPage,
        };
      }

      return {
        after,
        first: this.perPage,
      };
    },
    perPage() {
      return parseInt(this.$route.query.perPage || GRAPHQL_PAGE_SIZE, 10);
    },
    fields() {
      const columnWidth = 'gl-md-max-w-10 gl-whitespace-nowrap';

      return [
        {
          key: 'status',
          label: this.$options.i18n.tableHeaders.status,
          sortable: false,
          thClass: columnWidth,
          tdClass: columnWidth,
        },
        {
          key: 'check',
          label: this.$options.i18n.tableHeaders.check,
          sortable: false,
          thClass: columnWidth,
          tdClass: columnWidth,
        },
        {
          key: 'standard',
          label: this.$options.i18n.tableHeaders.standard,
          sortable: false,
          thClass: columnWidth,
          tdClass: columnWidth,
        },
        {
          key: 'project',
          label: this.$options.i18n.tableHeaders.project,
          sortable: false,
        },
        {
          key: 'lastScanned',
          label: this.$options.i18n.tableHeaders.lastScanned,
          sortable: false,
          thClass: columnWidth,
          tdClass: columnWidth,
        },
        {
          key: 'moreInformation',
          label: this.$options.i18n.tableHeaders.moreInformation,
          sortable: false,
          thClass: columnWidth,
          tdClass: columnWidth,
        },
      ];
    },
  },
  methods: {
    adherenceCheckName(check) {
      return STANDARDS_ADHERENCE_CHECK_LABELS[check];
    },
    adherenceStandardLabel(standard) {
      return STANDARDS_ADHERENCE_STANARD_LABELS[standard];
    },
    formatDate(dateString) {
      return formatDate(dateString, 'mmm d, yyyy');
    },
    isFailedStatus(status) {
      return status === FAIL_STATUS;
    },
    toggleDrawer(item) {
      if (this.drawerId === item.id) {
        this.closeDrawer();
      } else {
        this.trackEvent('click_standards_adherence_item_details', {
          property: item.id,
        });

        this.openDrawer(item);
      }
    },
    openDrawer(item) {
      this.drawerAdherence = item;
      this.drawerId = item.id;
    },
    closeDrawer() {
      this.drawerAdherence = {};
      this.drawerId = null;
    },
    loadPrevPage(startCursor) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: startCursor,
          after: undefined,
        },
      });
    },
    loadNextPage(endCursor) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: undefined,
          after: endCursor,
        },
      });
    },
    onPageSizeChange(perPage) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: undefined,
          after: undefined,
          perPage,
        },
      });
    },
  },
  noStandardsAdherencesFound: NO_STANDARDS_ADHERENCES_FOUND,
  standardsAdherenceFetchError: STANDARDS_ADHERENCE_FETCH_ERROR,
  i18n: {
    viewDetails: s__('ComplianceStandardsAdherence|View details'),
    viewDetailsFixAvailable: s__('ComplianceStandardsAdherence|View details (fix available)'),
    tableHeaders: {
      status: s__('ComplianceStandardsAdherence|Status'),
      project: s__('ComplianceStandardsAdherence|Project'),
      check: s__('ComplianceStandardsAdherence|Check'),
      standard: s__('ComplianceStandardsAdherence|Standard'),
      lastScanned: s__('ComplianceStandardsAdherence|Date since last status change'),
      moreInformation: s__('ComplianceStandardsAdherence|More information'),
    },
  },
};
</script>

<template>
  <section>
    <gl-alert
      v-if="hasStandardsAdherenceFetchError"
      variant="danger"
      class="gl-mt-3"
      :dismissible="false"
    >
      {{ customErrorText || $options.standardsAdherenceFetchError }}
    </gl-alert>
    <gl-table
      :fields="fields"
      :items="adherences.list"
      :busy="isLoading"
      :empty-text="$options.noStandardsAdherencesFound"
      show-empty
      stacked="lg"
      class="adherence-table-content"
    >
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #cell(status)="{ item: { status } }">
        <span v-if="isFailedStatus(status)" class="gl-text-danger">
          <gl-icon name="status_failed" /> {{ __('Fail') }}
        </span>
        <span v-else class="gl-text-success">
          <gl-icon name="status_success" variant="success" /> {{ __('Success') }}
        </span>
      </template>

      <template #cell(project)="{ item: { project } }">
        {{ project.name }}
        <frameworks-info
          v-if="project.complianceFrameworks.nodes.length"
          :frameworks="project.complianceFrameworks.nodes"
          :project-name="project.name"
          :show-edit-single-framework="isTopLevelGroup"
        />
      </template>

      <template #cell(check)="{ item: { checkName } }">
        {{ adherenceCheckName(checkName) }}
      </template>

      <template #cell(standard)="{ item }">
        {{ adherenceStandardLabel(item.standard) }}
      </template>

      <template #cell(lastScanned)="{ item: { updatedAt } }">
        {{ formatDate(updatedAt) }}
      </template>

      <template #cell(moreInformation)="{ item }">
        <gl-link @click="toggleDrawer(item)">
          <template v-if="isFailedStatus(item.status)">{{
            $options.i18n.viewDetailsFixAvailable
          }}</template>
          <template v-else>{{ $options.i18n.viewDetails }}</template>
        </gl-link>
      </template>
    </gl-table>
    <fix-suggestions-sidebar
      :show-drawer="showDrawer"
      :adherence="drawerAdherence"
      @close="closeDrawer"
    />
    <pagination
      v-if="showPagination"
      :is-loading="isLoading"
      :page-info="adherences.pageInfo"
      :per-page="perPage"
      @prev="loadPrevPage"
      @next="loadNextPage"
      @page-size-change="onPageSizeChange"
    />
  </section>
</template>
