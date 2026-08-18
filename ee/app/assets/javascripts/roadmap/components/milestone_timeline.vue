<script>
import CurrentDayIndicator from './current_day_indicator.vue';
import MilestoneItem from './milestone_item.vue';

export default {
  name: 'MilestoneTimeline',
  components: {
    MilestoneItem,
    CurrentDayIndicator,
  },
  props: {
    timeframe: {
      type: Array,
      required: true,
    },
    milestones: {
      type: Array,
      required: true,
    },
    milestonesExpanded: {
      type: Boolean,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <span
      v-for="timeframeItem in timeframe"
      :key="timeframeItem.id"
      class="milestone-timeline-cell !gl-border-r !gl-border-b gl-relative gl-table-cell !gl-border-b-gray-300 !gl-border-r-gray-300"
    >
      <current-day-indicator :timeframe-item="timeframeItem" />
      <template v-if="milestonesExpanded">
        <milestone-item
          v-for="milestone in milestones"
          :key="milestone.id"
          :milestone="milestone"
          :timeframe-item="timeframeItem"
        />
      </template>
    </span>
  </div>
</template>
