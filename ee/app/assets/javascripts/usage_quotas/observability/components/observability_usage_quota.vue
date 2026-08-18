<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import ObservabilityUsageBreakdown from './observability_usage_breakdown.vue';
import ObservabilityUsagePeriodSelector from './observability_usage_period_selector.vue';

export default {
  name: 'ObservabilityUsageQuotaApp',
  components: {
    GlLoadingIcon,
    ObservabilityUsageBreakdown,
    ObservabilityUsagePeriodSelector,
  },
  props: {
    observabilityClient: {
      type: Object,
      required: true,
    },
  },
  data() {
    const today = new Date();
    return {
      loading: false,
      selectedPeriod: {
        month: today.getMonth(),
        year: today.getFullYear(),
      },
      usageData: null,
    };
  },
  computed: {
    usageDataPeriod() {
      if (!this.selectedPeriod) {
        return null;
      }

      return {
        year: this.selectedPeriod.year,
        // 0-based index to 1-based index
        month: this.selectedPeriod.month + 1,
      };
    },
  },
  watch: {
    selectedPeriod() {
      this.fetchUsageData();
    },
  },
  created() {
    this.fetchUsageData();
  },
  methods: {
    async fetchUsageData() {
      this.loading = true;
      try {
        this.usageData = await this.observabilityClient.fetchUsageData({
          period: this.usageDataPeriod,
        });
      } catch (e) {
        createAlert({
          message: s__('Observability|Failed to load observability usage data.'),
        });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <section>
    <observability-usage-period-selector v-model="selectedPeriod" class="gl-mt-5" />

    <gl-loading-icon v-if="loading" size="lg" class="gl-mt-5" />

    <observability-usage-breakdown v-else-if="usageData" :usage-data="usageData" class="gl-pt-5" />
  </section>
</template>
