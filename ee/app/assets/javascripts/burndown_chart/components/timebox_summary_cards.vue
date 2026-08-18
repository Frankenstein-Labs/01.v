<script>
import { GlCard, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';

export default {
  name: 'TimeboxSummaryCards',
  cardBodyClass: 'gl-text-center gl-py-3 gl-text-size-h2',
  cardClass: 'gl-border-0 gl-mb-5',
  components: {
    GlCard,
    GlSkeletonLoader,
    GlSprintf,
  },
  props: {
    columns: {
      type: Array,
      required: false,
      default: () => [],
    },
    loading: {
      type: Boolean,
      required: true,
    },
    total: {
      type: Number,
      required: true,
    },
  },
  methods: {
    percent(val) {
      if (!this.total) return 0;
      return ((val / this.total) * 100).toFixed(0);
    },
  },
};
</script>

<template>
  <div class="row gl-mt-6">
    <div v-for="(column, index) in columns" :key="index" class="gl-col-sm-4">
      <gl-card :class="$options.cardClass" :body-class="$options.cardBodyClass">
        <gl-skeleton-loader v-if="loading" :width="400" :height="24">
          <rect x="100" y="4" width="120" height="20" rx="4" />
          <rect x="200" y="4" width="86" height="20" rx="4" />
        </gl-skeleton-loader>
        <div v-else>
          <span class="gl-mr-2 gl-border-1 gl-border-default gl-pr-3 gl-border-r-solid">
            {{ column.title }}
            <span class="gl-font-bold"
              >{{ percent(column.value) }}<small class="gl-text-subtle">%</small></span
            >
          </span>
          <gl-sprintf :message="__('%{count} of %{total}')">
            <template #count>
              <span class="gl-font-bold">{{ column.value }}</span>
            </template>
            <template #total>
              <span class="gl-font-bold">{{ total }}</span>
            </template>
          </gl-sprintf>
        </div>
      </gl-card>
    </div>
  </div>
</template>
