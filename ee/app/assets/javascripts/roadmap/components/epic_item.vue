<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';

import CommonMixin from '../mixins/common_mixin';
import MonthsPresetMixin from '../mixins/months_preset_mixin';
import QuartersPresetMixin from '../mixins/quarters_preset_mixin';
import WeeksPresetMixin from '../mixins/weeks_preset_mixin';

import epicChildEpics from '../queries/epic_child_epics.query.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';
import {
  formatRoadmapItemDetails,
  timeframeStartDate,
  timeframeEndDate,
} from '../utils/roadmap_item_utils';
import { mapLocalSettings } from '../utils/roadmap_utils';

import CurrentDayIndicator from './current_day_indicator.vue';

import EpicItemDetails from './epic_item_details.vue';
import EpicItemTimeline from './epic_item_timeline.vue';
import EpicItemContainer from './epic_item_container.vue';

export default {
  name: 'EpicItem',
  errorMessage: s__('GroupRoadmap|Something went wrong while fetching epics'),
  components: {
    CurrentDayIndicator,
    EpicItemDetails,
    EpicItemTimeline,
    EpicItemContainer,
  },
  mixins: [CommonMixin, QuartersPresetMixin, MonthsPresetMixin, WeeksPresetMixin],
  inject: ['currentGroupId'],
  props: {
    epic: {
      type: Object,
      required: true,
    },
    epicsHaveChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    clientWidth: {
      type: Number,
      required: false,
      default: 0,
    },
    childLevel: {
      type: Number,
      required: true,
    },
  },
  data() {
    const currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);

    return {
      // eslint-disable-next-line vue/no-unused-properties -- Used in CommonMixin logic (isTimeframeForToday) to compare with timeframeItem.
      currentDate,
      isExpanded: false,
      childEpics: [],
      localRoadmapSettings: null,
    };
  },
  apollo: {
    childEpics: {
      query: epicChildEpics,
      variables() {
        return {
          iid: this.epic.iid,
          fullPath: this.epic.group?.fullPath,
          state: this.epicsState,
          sort: this.sortedBy,
          ...this.filterParams,
        };
      },
      update(data) {
        const rawChildren = data.group.epic.children.nodes;

        return rawChildren.reduce((filteredChildren, epic) => {
          const { presetType, timeframe } = this;
          const formattedChild = formatRoadmapItemDetails(
            epic,
            timeframeStartDate(presetType, timeframe),
            timeframeEndDate(presetType, timeframe),
          );

          formattedChild.isChildEpic = true;

          // Exclude any Epic that has invalid dates
          if (formattedChild.startDate.getTime() <= formattedChild.endDate.getTime()) {
            filteredChildren.push(formattedChild);
          }
          return filteredChildren;
        }, []);
      },
      skip() {
        return !this.isExpanded || !this.localRoadmapSettings;
      },
      error() {
        createAlert({
          message: this.$options.errorMessage,
        });
      },
    },
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'epicsState',
      'sortedBy',
      'filterParams',
      'timeframe',
      'presetType',
      'isShowingLabels',
    ]),
    /**
     * In case Epic start date is out of range
     * we need to use original date instead of proxy date
     */
    startDate() {
      if (this.epic.startDateOutOfRange) {
        return this.epic.originalStartDate;
      }

      return this.epic.startDate;
    },
    /**
     * In case Epic end date is out of range
     * we need to use original date instead of proxy date
     */
    endDate() {
      if (this.epic.endDateOutOfRange) {
        return this.epic.originalEndDate;
      }
      return this.epic.endDate;
    },
    isChildrenEmpty() {
      return this.childEpics.length === 0;
    },
    hasChildrenToShow() {
      return this.isExpanded && this.childEpics?.length > 0;
    },
    isFetchingChildren() {
      return this.$apollo.queries.childEpics.loading;
    },
  },
  methods: {
    toggleEpic() {
      this.isExpanded = !this.isExpanded;
    },
  },
};
</script>

<template>
  <div class="epic-item-container">
    <div class="epics-list-item gl-flex gl-flex-row gl-items-stretch gl-clearfix">
      <epic-item-details
        :epic="epic"
        :epics-have-children="epicsHaveChildren"
        :timeframe-string="timeframeString(epic)"
        :child-level="childLevel"
        :is-expanded="isExpanded"
        :is-fetching-children="isFetchingChildren"
        :is-children-empty="isChildrenEmpty"
        :filter-params="filterParams"
        :is-showing-labels="isShowingLabels"
        @toggle-epic="toggleEpic"
      />
      <span
        v-for="(timeframeItem, index) in timeframe"
        :key="index"
        class="epic-timeline-cell gl-flex"
        data-testid="epic-timeline-cell"
      >
        <!--
          CurrentDayIndicator internally checks if a given timeframeItem is for today.
          However, we are doing a duplicate check (index === todaysIndex) here -
          so that the the indicator is rendered once.
          This optimization is only done in this component(EpicItem). -->
        <current-day-indicator
          v-if="index === todaysIndex"
          :preset-type="presetType"
          :timeframe-item="timeframeItem"
        />
        <epic-item-timeline
          v-if="index === roadmapItemIndex"
          :timeframe-item="timeframeItem"
          :epic="epic"
          :start-date="startDate"
          :end-date="endDate"
          :client-width="clientWidth"
        />
      </span>
    </div>
    <epic-item-container
      v-if="hasChildrenToShow"
      :epics-have-children="epicsHaveChildren"
      :client-width="clientWidth"
      :children="childEpics"
      :child-level="childLevel + 1"
    />
  </div>
</template>
