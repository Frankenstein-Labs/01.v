<script>
import { s__ } from '~/locale';
import StatsBarItem from './stats_bar_item.vue';

export default {
  name: 'StatsBar',
  components: {
    StatsBarItem,
  },
  props: {
    activePolicies: {
      type: Number,
      required: false,
      default: 0,
    },
    evaluationsThisWeek: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  i18n: {
    activePolicies: s__('PolicyStore|Active policies'),
    evaluationsThisWeek: s__('PolicyStore|Evaluations this week'),
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-5">
    <stats-bar-item :label="$options.i18n.activePolicies" :value="activePolicies" />
    <stats-bar-item :label="$options.i18n.evaluationsThisWeek" :value="evaluationsThisWeek" />
  </div>
</template>
