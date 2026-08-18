<script>
import DateRangeFilter from '~/ci/analytics/components/date_range_filter.vue';

export default {
  name: 'GroupPipelinesDashboardFilters',
  components: {
    DateRangeFilter,
  },
  props: {
    value: {
      type: Object,
      default: null,
      required: false,
    },
  },
  emits: ['input'],
  data() {
    return {
      dateRange: null,
    };
  },
  watch: {
    value: {
      handler() {
        const { dateRange } = this.value || {};
        this.dateRange = dateRange || null;
      },
      immediate: true,
    },
  },
  methods: {
    onSelect(param, value) {
      this[param] = value;

      this.$emit('input', {
        dateRange: this.dateRange,
      });
    },
  },
};
</script>
<template>
  <div>
    <date-range-filter
      id="date-range-filter"
      block
      :selected="dateRange"
      @select="onSelect('dateRange', $event)"
    />
  </div>
</template>
