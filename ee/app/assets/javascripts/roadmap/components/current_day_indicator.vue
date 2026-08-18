<script>
import CommonMixin from '../mixins/common_mixin';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';
import { mapLocalSettings } from '../utils/roadmap_utils';

export default {
  name: 'CurrentDayIndicator',
  mixins: [CommonMixin],
  props: {
    // eslint-disable-next-line vue/no-unused-properties -- This is used in hasToday via CommonMixin.
    timeframeItem: {
      type: [Date, Object],
      required: true,
    },
  },
  data() {
    const currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);

    return {
      // eslint-disable-next-line vue/no-unused-properties -- Used in CommonMixin logic (isTimeframeForToday) to compare with timeframeItem.
      currentDate,
      indicatorStyles: {},
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings(['presetType']),
  },
  mounted() {
    this.$nextTick(() => {
      this.indicatorStyles = this.getIndicatorStyles();
    });
  },
};
</script>

<template>
  <span
    v-if="hasToday"
    :style="indicatorStyles"
    class="current-day-indicator js-current-day-indicator gl-absolute"
  ></span>
</template>
