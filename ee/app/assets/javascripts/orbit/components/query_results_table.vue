<script>
import { defineComponent } from 'vue';
import { GlEmptyState, GlTable } from '@gitlab/ui';
import { s__ } from '~/locale';

const i18n = {
  emptyTitle: s__('Orbit|No results yet'),
  emptyDescription: s__('Orbit|Run a query to see results here.'),
};

export default defineComponent({
  name: 'QueryResultsTable',
  compatConfig: { MODE: 3 },
  components: {
    GlEmptyState,
    GlTable,
  },
  props: {
    rows: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  i18n,
  emits: ['row-click'],
  computed: {
    fields() {
      return Object.keys(this.rows[0] ?? {}).map((key) => ({
        key,
        label: key.replace(/_/g, ' '),
        sortable: true,
      }));
    },
  },
});
</script>

<template>
  <div data-testid="query-results-table">
    <gl-empty-state
      v-if="rows.length === 0"
      :title="$options.i18n.emptyTitle"
      :description="$options.i18n.emptyDescription"
      data-testid="results-empty-state"
    />

    <gl-table
      v-else
      :items="rows"
      :fields="fields"
      hover
      small
      stacked="md"
      class="gl-mb-0"
      @row-clicked="$emit('row-click', $event)"
    />
  </div>
</template>
