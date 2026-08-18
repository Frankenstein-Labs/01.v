<script>
import NO_DATA_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-chart-md.svg?url';
import { GlEmptyState } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'ObservabilityUsageNoData',
  NO_DATA_SVG,
  i18n: {
    title: s__('Observability|Sorry, there is no usage data for the selected period'),
    description: s__('Observability|Try selecting a different period.'),
  },
  components: {
    GlEmptyState,
  },
};
</script>

<template>
  <gl-empty-state :title="$options.i18n.title" :svg-path="$options.NO_DATA_SVG">
    <template #description>
      {{ $options.i18n.description }}
    </template>
  </gl-empty-state>
</template>
