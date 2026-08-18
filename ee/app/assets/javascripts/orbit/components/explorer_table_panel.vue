<script>
import { defineComponent } from 'vue';
import { GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import { downloadCsv } from '../utils/csv_export';
import QueryResultsTable from './query_results_table.vue';

const i18n = {
  csv: s__('Orbit|CSV'),
  emptyState: s__('Orbit|Run a query to see results'),
};

export default defineComponent({
  name: 'ExplorerTablePanel',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlIcon,
    GlLoadingIcon,
    QueryResultsTable,
  },
  props: {
    rows: {
      type: Array,
      required: false,
      default: () => [],
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n,
  emits: ['row-click'],
  computed: {
    hasResults() {
      return this.rows.length > 0;
    },
    resultsLabel() {
      return sprintf(n__('%{count} result', '%{count} results', this.rows.length), {
        count: this.rows.length,
      });
    },
  },
  methods: {
    handleDownloadCsv() {
      downloadCsv(this.rows);
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-flex-1 gl-flex-col gl-overflow-hidden" data-testid="explorer-table-panel">
    <gl-loading-icon v-if="loading" size="lg" class="gl-my-6" />

    <template v-else-if="hasResults">
      <div
        class="gl-flex gl-items-center gl-gap-2 gl-px-4 gl-py-2"
        data-testid="table-results-header"
      >
        <span class="gl-font-semibold">{{ resultsLabel }}</span>
        <div class="gl-flex-1"></div>
        <gl-button
          size="small"
          category="tertiary"
          icon="download"
          data-testid="download-csv-btn"
          @click="handleDownloadCsv"
        >
          {{ $options.i18n.csv }}
        </gl-button>
      </div>

      <div class="gl-flex-1 gl-overflow-auto">
        <query-results-table :rows="rows" @row-click="$emit('row-click', $event)" />
      </div>
    </template>

    <div v-else class="gl-flex gl-flex-1 gl-flex-col gl-items-center gl-justify-center gl-p-5">
      <gl-icon name="table" :size="24" class="gl-mb-2 gl-text-subtle" aria-hidden="true" />
      <p class="gl-mb-0 gl-text-sm gl-text-subtle" data-testid="table-empty-state">
        {{ $options.i18n.emptyState }}
      </p>
    </div>
  </div>
</template>
