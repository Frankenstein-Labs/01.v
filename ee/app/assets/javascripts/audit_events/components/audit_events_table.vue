<script>
import { GlKeysetPagination, GlTable } from '@gitlab/ui';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { getParameterValues, setUrlParams, visitUrl } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';

import ActionTableCell from './table_cells/action_table_cell.vue';
import UrlTableCell from './table_cells/url_table_cell.vue';

export default {
  name: 'AuditEventsTable',
  components: {
    ActionTableCell,
    GlTable,
    GlKeysetPagination,
    EmptyResult,
    UrlTableCell,
    UserDate,
  },
  props: {
    events: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLastPage: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    displayTable() {
      return this.events.length > 0;
    },
    hasPreviousPage() {
      return this.getCurrentPage() > 1;
    },
    hasNextPage() {
      return !this.isLastPage;
    },
  },
  methods: {
    getCurrentPage() {
      return parseInt(getParameterValues('page')[0], 10) || 1;
    },
    onPrev() {
      visitUrl(setUrlParams({ page: this.getCurrentPage() - 1 }));
    },
    onNext() {
      visitUrl(setUrlParams({ page: this.getCurrentPage() + 1 }));
    },
  },
  fields: [
    {
      key: 'author',
      label: s__('AuditLogs|Author'),
    },
    {
      key: 'object',
      label: s__('AuditLogs|Object'),
    },
    {
      key: 'action',
      label: s__('AuditLogs|Action'),
    },
    {
      key: 'target',
      label: s__('AuditLogs|Target'),
    },
    {
      key: 'ip_address',
      label: s__('AuditLogs|IP Address'),
      thStyle: { width: '20%' },
    },
    {
      key: 'date',
      label: s__('AuditLogs|Date'),
      thStyle: { width: '20%' },
    },
  ],
  dateTimeFormat: LONG_DATE_FORMAT_WITH_TZ,
};
</script>

<template>
  <div v-if="displayTable" class="audit-log-table" data-testid="audit-log-table">
    <gl-table
      class="gl-table-no-top-border"
      table-class="gl-table-layout-fixed"
      :fields="$options.fields"
      :items="events"
      show-empty
      stacked="md"
    >
      <template #cell(author)="{ value: { url, name } }">
        <url-table-cell :url="url" :name="name" />
      </template>
      <template #cell(object)="{ value: { url, name } }">
        <url-table-cell :url="url" :name="name" />
      </template>
      <template #cell(action)="{ value }">
        <action-table-cell :text="value" />
      </template>
      <template #cell(target)="{ value }">
        <span class="gl-wrap-anywhere">{{ value }}</span>
      </template>
      <template #cell(date)="{ value }">
        <user-date :date="value" :date-format="$options.dateTimeFormat" />
      </template>
    </gl-table>
    <gl-keyset-pagination
      class="gl-my-6 gl-flex gl-justify-center"
      :has-previous-page="hasPreviousPage"
      :has-next-page="hasNextPage"
      @prev="onPrev"
      @next="onNext"
    />
  </div>
  <empty-result v-else type="filter" />
</template>
