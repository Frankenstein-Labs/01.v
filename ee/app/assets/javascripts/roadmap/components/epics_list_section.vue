<script>
import { GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';

import { EPIC_DETAILS_CELL_WIDTH, TIMELINE_CELL_MIN_WIDTH, EPIC_ITEM_HEIGHT } from '../constants';
import eventHub from '../event_hub';
import { generateKey, scrollToCurrentDay } from '../utils/epic_utils';
import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';

import CurrentDayIndicator from './current_day_indicator.vue';
import EpicItem from './epic_item.vue';

export default {
  name: 'EpicsListSection',
  epicItemHeight: EPIC_ITEM_HEIGHT,
  components: {
    GlIntersectionObserver,
    GlLoadingIcon,
    EpicItem,
    CurrentDayIndicator,
  },
  inject: {
    epicIid: {
      default: null,
    },
  },
  props: {
    epics: {
      type: Array,
      required: true,
    },
    timeframe: {
      type: Array,
      required: true,
    },
    epicsFetchNextPageInProgress: {
      type: Boolean,
      required: true,
    },
    epicsHaveChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasNextPage: {
      type: Boolean,
      required: true,
    },
    bufferSize: {
      type: Number,
      required: true,
    },
  },
  emits: ['scrolled-to-end'],
  data() {
    return {
      clientWidth: 0,
      emptyRowContainerStyles: {},
      showBottomShadow: false,
      roadmapShellEl: null,
    };
  },
  computed: {
    isScopedRoadmap() {
      return Boolean(this.epicIid);
    },
    epicIds() {
      return this.epics.map((epic) => epic.id);
    },
    emptyRowContainerVisible() {
      return this.displayedEpics.length < this.bufferSize;
    },
    sectionContainerStyles() {
      return {
        height: `calc(100% - ${60 + this.milestonesHeight}px)`,
        width: `${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * this.timeframe.length}px`,
      };
    },
    footerMessageHeight() {
      return document.querySelector('.footer-message')?.getBoundingClientRect().height || 0;
    },
    milestonesHeight() {
      return document.querySelector('.milestones-list-section')?.clientHeight || 0;
    },
    epicsWithAssociatedParents() {
      return this.epics.filter((epic) => {
        if (epic.hasParent) {
          // In case `epic.parent` is null, user doesn't have access to parent and in that case, we just show current epic as is.
          if (epic.parent?.startDate && epic.parent?.dueDate) {
            return this.epicIds.indexOf(epic.parent.id) < 0;
          }
          return epic.ancestors.nodes.every((ancestor) => this.epicIds.indexOf(ancestor.id) < 0);
        }
        return !epic.hasParent;
      });
    },
    displayedEpics() {
      // If roadmap is accessed from epic, return all epics
      if (this.epicIid) {
        return this.epics;
      }

      // Return epics with correct parent associations.
      return this.epicsWithAssociatedParents;
    },
    scrollBarHeight() {
      return this.$parent.$el.getBoundingClientRect().height - this.$parent.$el.clientHeight + 1;
    },
  },
  mounted() {
    eventHub.$on('epicsListScrolled', this.handleEpicsListScroll);
    window.addEventListener('resize', this.syncClientWidth);
    this.initMounted();
  },
  beforeDestroy() {
    eventHub.$off('epicsListScrolled', this.handleEpicsListScroll);
    window.removeEventListener('resize', this.syncClientWidth);
  },
  methods: {
    setBufferSize(bufferSize) {
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: {
            bufferSize,
          },
        },
      });
    },
    initMounted() {
      const containerInnerHeight = this.isScopedRoadmap
        ? this.$root.$el.clientHeight
        : window.innerHeight;
      this.roadmapShellEl = this.$root.$el && this.$root.$el.querySelector('.js-roadmap-shell');
      this.setBufferSize(Math.ceil((containerInnerHeight - this.$el.offsetTop) / EPIC_ITEM_HEIGHT));

      // Wait for component render to complete
      this.$nextTick(() => {
        // We cannot scroll to the indicator immediately
        // on render as it will trigger scroll event leading
        // to timeline expand, so we wait for another render
        // cycle to complete.
        this.$nextTick(() => {
          scrollToCurrentDay(this.$el);
        });

        // Without setTimeout (or any form of deferred execution), when `getEmptyRowContainerStyles` function called,
        // the props that the function relies on aren't available yet, so props like `bufferSize`, `displayedEpics`
        // are still in process of initialization, and in that case, `emptyRowContainerStyles` is never initialised
        // causing the element not to get the style definition it needs. Also, using `$nextTick` doesn't help here.
        setTimeout(() => {
          if (!Object.keys(this.emptyRowContainerStyles).length) {
            this.emptyRowContainerStyles = this.getEmptyRowContainerStyles();
          }
        });
      });

      this.syncClientWidth();
    },
    syncClientWidth() {
      this.clientWidth = this.$root.$el?.clientWidth || 0;
    },
    getEmptyRowContainerStyles() {
      if (this.displayedEpics.length && this.$refs.emptyRowContainer) {
        const { top } = this.$refs.emptyRowContainer.getBoundingClientRect();
        const { offsetTop } = this.$refs.emptyRowContainer;
        return {
          height: this.isScopedRoadmap
            ? `calc(${this.$root.$el.clientHeight}px - ${offsetTop}px)`
            : `calc(100vh - ${top + this.scrollBarHeight + this.footerMessageHeight}px)`,
        };
      }
      return {};
    },
    handleEpicsListScroll({ scrollTop, clientHeight, scrollHeight }) {
      this.showBottomShadow = Math.ceil(scrollTop) + clientHeight < scrollHeight;
    },
    handleScrolledToEnd() {
      this.$emit('scrolled-to-end');
    },
    generateKey,
  },
};
</script>

<template>
  <div :style="sectionContainerStyles" class="epics-list-section">
    <epic-item
      v-for="epic in displayedEpics"
      ref="epicItems"
      :key="generateKey(epic)"
      :epic="epic"
      :epics-have-children="epicsHaveChildren"
      :timeframe="timeframe"
      :client-width="clientWidth"
      :child-level="0"
    />
    <div v-if="emptyRowContainerVisible" class="epic-item-container">
      <div
        ref="emptyRowContainer"
        :style="emptyRowContainerStyles"
        class="epics-list-item epics-list-item-empty gl-clearfix"
      >
        <span class="epic-details-cell"></span>
        <span
          v-for="(timeframeItem, index) in timeframe"
          :key="index"
          class="epic-timeline-cell gl-flex"
        >
          <current-day-indicator :timeframe-item="timeframeItem" />
        </span>
      </div>
    </div>
    <gl-intersection-observer v-if="hasNextPage" @appear="handleScrolledToEnd">
      <div
        v-if="epicsFetchNextPageInProgress"
        class="gl-py-3 gl-text-center"
        data-testid="next-page-loading"
      >
        <gl-loading-icon inline class="gl-mr-2" />
        {{ s__('GroupRoadmap|Loading epics') }}
      </div>
    </gl-intersection-observer>
    <div
      v-show="showBottomShadow"
      data-testid="epic-scroll-bottom-shadow"
      class="epic-scroll-bottom-shadow gl-left-auto"
    ></div>
  </div>
</template>
