<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';

import groupMilestones from '../queries/group_milestones.query.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';
import { getEpicsTimeframeRange, mapLocalSettings } from '../utils/roadmap_utils';
import {
  formatRoadmapItemDetails,
  timeframeStartDate,
  timeframeEndDate,
} from '../utils/roadmap_item_utils';

import eventHub from '../event_hub';
import { MILESTONES_GROUP, MILESTONES_SUBGROUP, MILESTONES_PROJECT } from '../constants';

import EpicsListSection from './epics_list_section.vue';
import MilestonesListSection from './milestones_list_section.vue';
import RoadmapTimelineSection from './roadmap_timeline_section.vue';

export default {
  name: 'RoadmapShell',
  components: {
    EpicsListSection,
    MilestonesListSection,
    RoadmapTimelineSection,
  },
  inject: ['fullPath', 'epicIid'],
  props: {
    epics: {
      type: Array,
      required: true,
    },
    epicsFetchNextPageInProgress: {
      type: Boolean,
      required: true,
    },
    hasNextPage: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['scrolled-to-end'],
  data() {
    return {
      containerStyles: {},
      canCalculateEpicsListHeight: false,
      milestones: [],
      // eslint-disable-next-line vue/no-unused-properties -- This is used in Apollo query
      localRoadmapSettings: {},
    };
  },
  apollo: {
    milestones: {
      query: groupMilestones,
      variables() {
        return {
          fullPath: this.fullPath,
          state: 'active',
          ...getEpicsTimeframeRange({
            presetType: this.presetType,
            timeframe: this.timeframe,
          }),
          includeDescendants: true,
          includeAncestors: true,
          searchTitle: this.filterParams.milestoneTitle,
        };
      },
      skip() {
        return !this.isShowingMilestones;
      },
      update(data) {
        const rawMilestones = data.group.milestones.nodes;
        return rawMilestones.reduce((filteredMilestones, milestone) => {
          const formattedMilestone = formatRoadmapItemDetails(
            milestone,
            timeframeStartDate(this.presetType, this.timeframe),
            timeframeEndDate(this.presetType, this.timeframe),
          );
          // Exclude any Milestone that has invalid dates
          // or is already present in Roadmap timeline
          if (formattedMilestone.startDate.getTime() <= formattedMilestone.endDate.getTime()) {
            filteredMilestones.push(formattedMilestone);
          }
          return filteredMilestones;
        }, []);
      },
      error() {
        createAlert({
          message: s__('GroupRoadmap|Something went wrong while fetching milestones'),
        });
      },
    },
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'isShowingMilestones',
      'milestonesType',
      'bufferSize',
      'timeframe',
      'filterParams',
      'presetType',
    ]),
    isScopedRoadmap() {
      return Boolean(this.epicIid);
    },
    displayMilestones() {
      return Boolean(this.milestones.length) && this.isShowingMilestones;
    },
    milestonesToShow() {
      switch (this.milestonesType) {
        case MILESTONES_GROUP:
          return this.milestones.filter((m) => m.groupMilestone && !m.subgroupMilestone);
        case MILESTONES_SUBGROUP:
          return this.milestones.filter((m) => m.subgroupMilestone);
        case MILESTONES_PROJECT:
          return this.milestones.filter((m) => m.projectMilestone);
        default:
          return this.milestones;
      }
    },
    footerMessageHeight() {
      return document.querySelector('.footer-message')?.getBoundingClientRect().height || 0;
    },
    epicsHaveChildren() {
      return this.epics.some((epic) => epic.hasChildren);
    },
  },
  mounted() {
    this.$nextTick(() => {
      this.containerStyles = this.getContainerStyles();
    });
  },
  methods: {
    handleScroll() {
      const { scrollTop, scrollLeft, clientHeight, scrollHeight } = this.$el;

      eventHub.$emit('epicsListScrolled', { scrollTop, scrollLeft, clientHeight, scrollHeight });
    },
    getContainerStyles() {
      const { top } = this.$el.getBoundingClientRect();
      return {
        height: this.isScopedRoadmap ? '100%' : `calc(100vh - ${top + this.footerMessageHeight}px)`,
      };
    },
    toggleCanCalculateEpicsListHeight() {
      this.canCalculateEpicsListHeight = true;
    },
  },
};
</script>

<template>
  <div
    class="js-roadmap-shell gl-relative gl-w-full gl-overflow-x-auto"
    data-testid="roadmap-shell"
    :style="containerStyles"
    @scroll="handleScroll"
  >
    <roadmap-timeline-section
      ref="roadmapTimeline"
      :preset-type="presetType"
      :timeframe="timeframe"
    />
    <milestones-list-section
      v-if="displayMilestones"
      :milestones="milestonesToShow"
      :timeframe="timeframe"
      @milestones-mounted="toggleCanCalculateEpicsListHeight"
    />
    <epics-list-section
      :key="canCalculateEpicsListHeight"
      :epics="epics"
      :timeframe="timeframe"
      :epics-fetch-next-page-in-progress="epicsFetchNextPageInProgress"
      :epics-have-children="epicsHaveChildren"
      :has-next-page="hasNextPage"
      :buffer-size="bufferSize"
      @scrolled-to-end="$emit('scrolled-to-end')"
    />
  </div>
</template>
