<script>
import { GlBadge, GlTab, GlTabs } from '@gitlab/ui';
import { formatNumber } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'MergeTrainTabs',
  components: {
    GlBadge,
    GlTab,
    GlTabs,
  },
  mixins: [glSlotsMixin],
  props: {
    activeTrain: {
      type: Object,
      required: true,
    },
    mergedTrain: {
      type: Object,
      required: true,
    },
  },
  emits: ['active-tab'],
  computed: {
    activeCarCount() {
      return formatNumber(this.activeTrain?.cars?.count || 0);
    },
    mergedCarCount() {
      return formatNumber(this.mergedTrain?.cars?.count || 0);
    },
  },
};
</script>

<template>
  <gl-tabs sync-active-tab-with-query-params lazy @input="$emit('active-tab', $event)">
    <gl-tab query-param-value="active" data-testid="active-cars-tab">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Active') }}</span>
        <gl-badge>
          {{ activeCarCount }}
        </gl-badge>
      </template>
      <template v-if="glSlots().active" #default><slot name="active"></slot></template>
    </gl-tab>
    <gl-tab query-param-value="merged" data-testid="merged-cars-tab">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Merged') }}</span>
        <gl-badge>
          {{ mergedCarCount }}
        </gl-badge>
      </template>
      <template v-if="glSlots().merged" #default><slot name="merged"></slot></template>
    </gl-tab>
  </gl-tabs>
</template>
