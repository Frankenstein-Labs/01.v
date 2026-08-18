<script>
import { GlSprintf } from '@gitlab/ui';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import { numberToHumanSize, numberToMetricPrefix } from '~/lib/utils/number_utils';
import { s__ } from '~/locale';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';

export default {
  name: 'ObservabilityUsageSectionedBar',
  components: {
    SectionedPercentageBar,
    NumberToHumanSize,
    GlSprintf,
  },
  i18n: {
    eventsTotal: s__('Observability|%{events} events'),
  },
  props: {
    usageData: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isBytes() {
      return this.usageData.data_unit === 'bytes';
    },
    usageTotal() {
      return this.usageData.data_unit === 'bytes'
        ? this.usageData.aggregated_total
        : numberToMetricPrefix(this.usageData.aggregated_total, true);
    },
    sectionedUsage() {
      const data = this.usageData.aggregated_per_feature;
      return Object.entries(data).map(([key, value]) => ({
        id: key,
        label: key,
        value,
        formattedValue: this.isBytes ? numberToHumanSize(value) : numberToMetricPrefix(value, true),
      }));
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-flex gl-flex-col gl-items-end gl-text-size-h1 gl-font-bold">
      <number-to-human-size v-if="isBytes" :value="usageTotal" :fraction-digits="2" />
      <gl-sprintf v-else :message="$options.i18n.eventsTotal">
        <template #events>{{ usageTotal }}</template>
      </gl-sprintf>
    </div>

    <sectioned-percentage-bar class="gl-mt-5" :sections="sectionedUsage" />
  </div>
</template>
