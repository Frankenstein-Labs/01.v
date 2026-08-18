<script>
import { GlEmptyState } from '@gitlab/ui';

import { GL_LIGHT } from '~/constants';
import { ROUTE_STANDARDS_ADHERENCE } from '../../constants';
import StatusChart from './components/status_chart.vue';

export default {
  name: 'FailedRequirements',
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
    failedRequirements: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEmpty() {
      const { passed, failed, pending } = this.failedRequirements;
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
    :x-axis-title="s__('ComplianceReport|Requirements')"
    :data="failedRequirements"
    :path="$options.ROUTE_STANDARDS_ADHERENCE"
  />
  <gl-empty-state
    v-else
    :title="s__('ComplianceReport|There are no requirements.')"
    :description="s__('ComplianceReport|You can add requirements inside the compliance framework.')"
    class="gl-m-0 gl-pt-3"
  />
</template>
