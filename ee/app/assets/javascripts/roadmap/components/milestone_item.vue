<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { __ } from '~/locale';
import { TIMELINE_CELL_MIN_WIDTH, SCROLL_BAR_SIZE } from '../constants';
import CommonMixin from '../mixins/common_mixin';
import MonthsPresetMixin from '../mixins/months_preset_mixin';
import QuartersPresetMixin from '../mixins/quarters_preset_mixin';
import WeeksPresetMixin from '../mixins/weeks_preset_mixin';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';
import { mapLocalSettings } from '../utils/roadmap_utils';

export default {
  name: 'MilestoneItem',
  cellWidth: TIMELINE_CELL_MIN_WIDTH,
  components: {
    GlIcon,
    GlPopover,
  },
  mixins: [CommonMixin, QuartersPresetMixin, MonthsPresetMixin, WeeksPresetMixin],
  props: {
    // eslint-disable-next-line vue/no-unused-properties -- `timeFrameItem` used by the `CommonMixin` mixin
    timeframeItem: {
      type: [Date, Object],
      required: true,
    },
    milestone: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      hoverStyles: {},
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings(['presetType', 'timeframe']),
    // eslint-disable-next-line vue/no-unused-properties -- `startDate` used by the `CommonMixin` mixin
    startDate() {
      return this.milestone.startDateOutOfRange
        ? this.milestone.originalStartDate
        : this.milestone.startDate;
    },
    // eslint-disable-next-line vue/no-unused-properties -- `endDate` used by the `CommonMixin` mixin
    endDate() {
      return this.milestone.endDateOutOfRange
        ? this.milestone.originalEndDate
        : this.milestone.endDate;
    },
    smallClass() {
      const smallStyleClass = 'milestone-small';
      const minimumStyleClass = 'milestone-minimum';
      if (this.presetTypeQuarters) {
        const width = this.getTimelineBarWidthForQuarters(this.milestone);
        if (width < 9) {
          return minimumStyleClass;
        }
        if (width < 12) {
          return smallStyleClass;
        }
      } else if (this.presetTypeMonths) {
        const width = this.getTimelineBarWidthForMonths();
        if (width < 12) {
          return smallStyleClass;
        }
      }
      return '';
    },
    milestoneType() {
      const { subgroupMilestone, projectMilestone } = this.milestone;
      if (projectMilestone) {
        return __('Project milestone');
      }
      if (subgroupMilestone) {
        return __('Subgroup milestone');
      }

      return __('Group milestone');
    },
    typeIcon() {
      const { subgroupMilestone, projectMilestone } = this.milestone;
      if (projectMilestone) {
        return 'project';
      }
      if (subgroupMilestone) {
        return 'subgroup';
      }

      return 'group';
    },
  },
  mounted() {
    this.$nextTick(() => {
      this.hoverStyles = this.getHoverStyles();
    });
  },
  methods: {
    getHoverStyles() {
      const elHeight = this.$root.$el.getBoundingClientRect().y;
      return {
        height: `calc(100vh - ${elHeight + SCROLL_BAR_SIZE}px)`,
      };
    },
  },
};
</script>

<template>
  <div class="timeline-bar-wrapper">
    <span
      v-if="hasStartDate"
      :class="[
        {
          'start-date-undefined': milestone.startDateUndefined,
          'end-date-undefined': milestone.endDateUndefined,
        },
        smallClass,
      ]"
      :style="timelineBarStyles(milestone)"
      class="milestone-item-details !gl-absolute gl-inline-block"
      data-testid="milestone-item-wrapper"
    >
      <a :href="milestone.webPath" class="milestone-url gl-block">
        <span
          :id="`milestone-item-${milestone.id}`"
          class="milestone-item-title str-truncated-100 gl-sticky gl-font-bold"
          >{{ milestone.title }}</span
        >
        <span class="timeline-bar gl-relative gl-block"></span>
      </a>
      <div class="milestone-start-and-end gl-relative" :style="hoverStyles"></div>
      <gl-popover
        :target="`milestone-item-${milestone.id}`"
        boundary="viewport"
        placement="left"
        :title="milestone.title"
      >
        <div class="milestone-item-type gl-leading-normal">
          <gl-icon :name="typeIcon" class="gl-align-middle" />
          <span class="gl-inline-block gl-align-middle">{{ milestoneType }}</span>
        </div>
        <div class="milestone-item-date">{{ timeframeString(milestone) }}</div>
      </gl-popover>
    </span>
  </div>
</template>
