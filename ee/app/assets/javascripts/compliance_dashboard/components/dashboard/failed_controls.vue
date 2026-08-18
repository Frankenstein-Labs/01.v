<script>
import { GlEmptyState } from '@gitlab/ui';

import { GL_LIGHT } from '~/constants';
import { ROUTE_STANDARDS_ADHERENCE } from '../../constants';
import StatusChart from './components/status_chart.vue';

export default {
  name: 'FailedControls',
  components: {
    GlEmptyState,
    StatusChart,
  },
  props: {
    colorScheme: {
      type: String,
      required: false,
      default: GL_LIGHT,
    },
    failedControls: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEmpty() {
      const { passed, failed, pending } = this.failedControls;
      return passed + failed + pending === 0;
    },
  },

  ROUTE_STANDARDS_ADHERENCE,
};
</script>

<template>
  <status-chart
    v-if="!isEmpty"
    :legend="$options.legend"
    :color-scheme="colorScheme"
    :data="failedControls"
    :x-axis-title="s__('ComplianceReport|Controls')"
    :path="$options.ROUTE_STANDARDS_ADHERENCE"
  />
  <gl-empty-state
    v-else
    :title="s__('ComplianceReport|There are no controls.')"
    :description="
      s__('ComplianceReport|You can add controls for requirements inside the compliance framework.')
    "
    class="gl-m-0 gl-pt-3"
  />
</template>
