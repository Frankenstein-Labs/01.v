<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import { createToken } from '../token_utils';
import AuditEventsExportButton from './audit_events_export_button.vue';
import AuditEventsFilter from './audit_events_filter.vue';
import AuditEventsTable from './audit_events_table.vue';
import DateRangeField from './date_range_field.vue';
import SortingField from './sorting_field.vue';

export default {
  name: 'AuditEventsLog',
  components: {
    AuditEventsFilter,
    DateRangeField,
    SortingField,
    AuditEventsTable,
    AuditEventsExportButton,
  },
  inject: [
    'events',
    'isLastPage',
    'filterTokenOptions',
    'exportUrl',
    'filterViewOnly',
    'filterTokenValues',
  ],
  computed: {
    ...mapState(['filterValue', 'startDate', 'endDate', 'sortBy']),
    ...mapGetters(['buildExportHref']),
    exportHref() {
      return this.buildExportHref(this.exportUrl);
    },
    hasExportUrl() {
      return this.exportUrl.length;
    },
  },
  created() {
    if (this.filterTokenValues.length > 0) {
      this.setFilterValue(this.filterTokenValues.map(createToken));
    }
  },
  methods: {
    ...mapActions(['setDateRange', 'setFilterValue', 'setSortBy', 'searchForAuditEvents']),
  },
};
</script>

<template>
  <div>
    <div class="row-content-block gl-border-t-0">
      <div class="gl-mb-3 gl-flex gl-flex-col gl-gap-3 @md/panel:gl-flex-row">
        <audit-events-filter
          :filter-token-options="filterTokenOptions"
          :value="filterValue"
          :view-only="filterViewOnly"
          @selected="setFilterValue"
          @submit="searchForAuditEvents"
        />
        <sorting-field :sort-by="sortBy" @selected="setSortBy" />
        <audit-events-export-button v-if="hasExportUrl" :export-href="exportHref" />
      </div>
      <date-range-field :start-date="startDate" :end-date="endDate" @selected="setDateRange" />
    </div>
    <audit-events-table :events="events" :is-last-page="isLastPage" />
  </div>
</template>
