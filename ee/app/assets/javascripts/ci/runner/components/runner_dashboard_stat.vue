<script>
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { formatNumber } from '~/locale';
import { INSTANCE_TYPE, GROUP_TYPE } from '~/ci/runner/constants';
import RunnerCount from '~/ci/runner/components/stat/runner_count.vue';

export default {
  name: 'RunnerDashboardStat',
  components: {
    RunnerCount,
    GlSingleStat,
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (val) => [INSTANCE_TYPE, GROUP_TYPE].includes(val),
    },
    variables: {
      type: Object,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    icon: {
      type: String,
      required: false,
      default: null,
    },
    iconClass: {
      type: String,
      required: false,
      default: null,
    },
  },
  methods: {
    formattedValue(value) {
      if (typeof value === 'number') {
        return formatNumber(value);
      }
      return '-';
    },
  },
  INSTANCE_TYPE,
};
</script>

<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <runner-count #default="{ count }" :scope="scope" :variables="variables">
      <gl-single-stat
        :title-icon="icon"
        :title-icon-class="iconClass"
        :title="title"
        :value="formattedValue(count)"
      />
    </runner-count>
  </div>
</template>
