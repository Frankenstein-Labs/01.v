<script>
import { debounce } from 'lodash-es';
import { PanelBreakpointInstance } from '~/panel_breakpoint_instance';
import { EPIC_DETAILS_CELL_WIDTH, TIMELINE_CELL_MIN_WIDTH } from '../constants';
import eventHub from '../event_hub';

import CommonMixin from '../mixins/common_mixin';

import MonthsHeaderItem from './preset_months/months_header_item.vue';
import QuartersHeaderItem from './preset_quarters/quarters_header_item.vue';
import WeeksHeaderItem from './preset_weeks/weeks_header_item.vue';

export default {
  name: 'RoadmapTimelineSection',
  components: {
    QuartersHeaderItem,
    MonthsHeaderItem,
    WeeksHeaderItem,
  },
  mixins: [CommonMixin],
  props: {
    // eslint-disable-next-line vue/no-unused-properties -- This is used in headerItemComponentForPreset via CommonMixin.
    presetType: {
      type: String,
      required: true,
    },
    timeframe: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      scrolledHeaderClass: '',
      rightSpacing: 16,
    };
  },
  computed: {
    headerItemComponentForPreset() {
      if (this.presetTypeQuarters) {
        return 'quarters-header-item';
      }
      if (this.presetTypeMonths) {
        return 'months-header-item';
      }
      if (this.presetTypeWeeks) {
        return 'weeks-header-item';
      }
      return '';
    },
    sectionContainerStyles() {
      return {
        width: `${
          EPIC_DETAILS_CELL_WIDTH +
          TIMELINE_CELL_MIN_WIDTH * this.timeframe.length +
          this.rightSpacing
        }px`,
      };
    },
  },
  created() {
    this.setRightSpacing();

    const resizeThrottled = debounce(() => {
      this.setRightSpacing();
    }, 400);

    window.addEventListener('resize', resizeThrottled);
  },
  destroyed() {
    window.removeEventListener('resize', this.setRightSpacing);
  },
  mounted() {
    eventHub.$on('epicsListScrolled', this.handleEpicsListScroll);
  },
  beforeDestroy() {
    eventHub.$off('epicsListScrolled', this.handleEpicsListScroll);
  },
  methods: {
    handleEpicsListScroll({ scrollTop }) {
      // Add class only when epics list is scrolled at 1% the height of header
      this.scrolledHeaderClass = scrollTop > this.$el.clientHeight / 100 ? 'scroll-top-shadow' : '';
    },
    setRightSpacing() {
      // To support browsers other than chromium, we need to add 16 or 24px to
      // the actual width of the timeline section instead of using utility
      // classes like "gl-mr-5 @xl/panel:gl-mr-6". This will set the specing to 16px
      // when the viewport is smaller than our xl breakpoint, and 24px if it's
      // xl or larger.
      this.rightSpacing = PanelBreakpointInstance.getBreakpointSize() === 'xl' ? 24 : 16;
    },
  },
};
</script>

<template>
  <div
    :class="scrolledHeaderClass"
    :style="sectionContainerStyles"
    class="roadmap-timeline-section gl-clearfix"
  >
    <span class="timeline-header-blank"></span>
    <component
      :is="headerItemComponentForPreset"
      v-for="(timeframeItem, index) in timeframe"
      :key="index"
      :timeframe-index="index"
      :timeframe-item="timeframeItem"
      :timeframe="timeframe"
    />
  </div>
</template>
