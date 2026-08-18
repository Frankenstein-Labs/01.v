<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { DOCS_URL } from '~/constants';
import ObservabilityUsageChart from './observability_usage_chart.vue';
import ObservabilityUsageSectionedBar from './observability_usage_sectioned_bar.vue';
import ObservabilityUsageNoData from './observability_usage_no_data.vue';

export default {
  name: 'ObservabilityUsageBreakdown',
  i18n: {
    title: __('Usage breakdown'),
    subtitle: s__('Observability|Includes Logs, Traces and Metrics. %{learnMoreLink}'),
    learnMoreLinkText: __('Learn more.'),
    dayUsageTitle: s__('Observability|Usage by day'),
    eventsChartTitle: __('Events'),
    storageChartTitle: __('Storage'),
  },
  docsLink: `${DOCS_URL}/operations`,
  components: {
    GlSprintf,
    GlLink,
    ObservabilityUsageChart,
    ObservabilityUsageSectionedBar,
    ObservabilityUsageNoData,
  },
  props: {
    usageData: {
      type: Object,
      required: true,
    },
  },
  computed: {
    eventsData() {
      if (!this.usageData) return null;

      return Object.values(this.usageData.events)[0];
    },
    storageData() {
      if (!this.usageData) return null;

      return Object.values(this.usageData.storage)[0];
    },
  },
};
</script>

<template>
  <section class="gl-flex gl-flex-col gl-gap-y-5">
    <div>
      <h3 class="gl-heading-3">{{ $options.i18n.title }}</h3>
      <p>
        <gl-sprintf :message="$options.i18n.subtitle">
          <template #learnMoreLink>
            <gl-link target="_blank" :href="$options.docsLink">
              <span>{{ $options.i18n.learnMoreLinkText }}</span>
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>

    <observability-usage-no-data v-if="!storageData && !eventsData" />

    <template v-else>
      <observability-usage-sectioned-bar
        v-if="storageData"
        :usage-data="storageData"
        data-testid="sectioned-storage-usage"
      />

      <observability-usage-sectioned-bar
        v-if="eventsData"
        :usage-data="eventsData"
        data-testid="sectioned-events-usage"
      />

      <h2 class="gl-heading-4 gl-mt-8">{{ $options.i18n.dayUsageTitle }}</h2>

      <observability-usage-chart
        v-if="storageData"
        :title="$options.i18n.storageChartTitle"
        :usage-data="storageData"
        :unit="storageData"
        data-testid="storage-usage-chart"
      />

      <observability-usage-chart
        v-if="eventsData"
        :title="$options.i18n.eventsChartTitle"
        :usage-data="eventsData"
        data-testid="events-usage-chart"
      />
    </template>
  </section>
</template>
