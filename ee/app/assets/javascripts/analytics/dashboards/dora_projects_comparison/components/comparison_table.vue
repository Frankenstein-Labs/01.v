<script>
import { GlTable, GlAvatarLabeled } from '@gitlab/ui';
import { sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DASHBOARD_NO_DATA_FOR_GROUP } from '../../constants';
import { TABLE_FIELDS, DEFAULT_TABLE_SORT_COLUMN } from '../constants';
import MetricTableCell from './metric_table_cell.vue';

export default {
  name: 'ComparisonTable',
  TABLE_FIELDS,
  components: {
    GlTable,
    GlAvatarLabeled,
    MetricTableCell,
  },
  inject: ['namespaceFullPath'],
  props: {
    projects: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      sortBy: DEFAULT_TABLE_SORT_COLUMN,
      sortDesc: true,
    };
  },
  computed: {
    noDataMessage() {
      if (this.projects.length > 0) return '';

      return sprintf(DASHBOARD_NO_DATA_FOR_GROUP, {
        fullPath: this.namespaceFullPath,
      });
    },
  },
  methods: {
    getAvatarEntityId(gid) {
      return getIdFromGraphQLId(gid);
    },
    rowAttributes({ id }) {
      return {
        'data-testid': `project-${getIdFromGraphQLId(id)}`,
      };
    },
  },
};
</script>

<template>
  <div>
    <div v-if="noDataMessage" class="gl-text-center gl-text-subtle">
      {{ noDataMessage }}
    </div>

    <gl-table
      v-else
      :fields="$options.TABLE_FIELDS"
      :items="projects"
      :sort-by.sync="sortBy"
      :sort-desc.sync="sortDesc"
      :tbody-tr-attr="rowAttributes"
      table-class="gl-table-fixed"
    >
      <template #cell(name)="{ value, item: { id, name, avatarUrl, webUrl } }">
        <gl-avatar-labeled
          :src="avatarUrl"
          :size="24"
          :label="value"
          :label-link="webUrl"
          :entity-id="getAvatarEntityId(id)"
          :entity-name="name"
          fallback-on-error
          shape="rect"
        />
      </template>

      <template #cell()="{ value, item: { trends }, field: { key } }">
        <metric-table-cell :value="value" :metric-type="key" :trend="trends[key]" />
      </template>
    </gl-table>
  </div>
</template>
