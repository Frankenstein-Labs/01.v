<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';

import RoadmapShell from 'jh_else_ee/roadmap/components/roadmap_shell.vue';

import { createAlert } from '~/alert';
import { s__ } from '~/locale';

import { getEpicsTimeframeRange, mapLocalSettings } from '../utils/roadmap_utils';
import { transformFetchEpicFilterParams } from '../utils/epic_utils';
import { ROADMAP_PAGE_SIZE } from '../constants';
import {
  formatRoadmapItemDetails,
  timeframeStartDate,
  timeframeEndDate,
} from '../utils/roadmap_item_utils';
import epicChildEpics from '../queries/epic_child_epics.query.graphql';
import groupEpicsWithColor from '../queries/group_epics_with_color.query.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';

import EpicsListEmpty from './epics_list_empty.vue';
import RoadmapFilters from './roadmap_filters.vue';
import RoadmapSettings from './roadmap_settings.vue';

export default {
  name: 'RoadmapApp',
  epicsFetchError: s__('GroupRoadmap|Something went wrong while fetching epics'),
  components: {
    EpicsListEmpty,
    GlLoadingIcon,
    RoadmapFilters,
    RoadmapSettings,
    RoadmapShell,
  },
  inject: ['epicIid', 'fullPath'],
  data() {
    return {
      isSettingsSidebarOpen: false,
      rawEpics: {},
      epicsFetchFailure: false,
      epicsFetchNextPageInProgress: false,
      localRoadmapSettings: null,
    };
  },
  apollo: {
    rawEpics: {
      query() {
        return this.epicsQuery;
      },
      variables() {
        return { ...this.epicsQueryVariables };
      },
      update(data) {
        return this.epicIid ? data?.group?.epic?.children : data?.group?.epics;
      },
      skip() {
        return !this.localRoadmapSettings;
      },
      error() {
        this.epicsFetchFailure = true;
        createAlert({
          message: this.$options.epicsFetchError,
        });
      },
    },
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'filterParams',
      'timeframe',
      'presetType',
      'timeframeRangeType',
      'epicsState',
      'sortedBy',
    ]),
    epicsQuery() {
      if (this.epicIid) {
        return epicChildEpics;
      }
      return groupEpicsWithColor;
    },
    epicsQueryVariables() {
      let variables = {
        fullPath: this.fullPath,
        state: this.epicsState,
        sort: this.sortedBy,
        ...getEpicsTimeframeRange({
          presetType: this.presetType,
          timeframe: this.timeframe,
        }),
      };

      const transformedFilterParams = transformFetchEpicFilterParams(this.filterParams);

      if (this.epicIid) {
        variables.iid = this.epicIid;
      } else {
        variables = {
          ...variables,
          ...transformedFilterParams,
          first: ROADMAP_PAGE_SIZE,
          endCursor: '',
        };

        if (transformedFilterParams?.epicIid) {
          variables.iid = transformedFilterParams.epicIid.split('::&').pop();
        }
        if (transformedFilterParams?.groupPath) {
          variables.fullPath = transformedFilterParams.groupPath;
          variables.includeDescendantGroups = false;
        }
      }

      return variables;
    },
    epics() {
      const epics = this.rawEpics.nodes || [];
      return epics.reduce((filteredEpics, epic) => {
        const { presetType, timeframe } = this;
        const formattedEpic = formatRoadmapItemDetails(
          epic,
          timeframeStartDate(presetType, timeframe),
          timeframeEndDate(presetType, timeframe),
        );

        formattedEpic.isChildEpic = true;

        // Exclude any Epic that has invalid dates
        // or is already present in Roadmap timeline
        if (formattedEpic.startDate.getTime() <= formattedEpic.endDate.getTime()) {
          filteredEpics.push(formattedEpic);
        }

        return filteredEpics;
      }, []);
    },
    epicsFetchResultEmpty() {
      return this.epics.length === 0;
    },
    epicsFetchInProgress() {
      return this.$apollo.queries.rawEpics.loading && !this.epicsFetchNextPageInProgress;
    },
    hasFiltersApplied() {
      return !isEmpty(this.filterParams);
    },
    hasNextPage() {
      return Boolean(this.rawEpics.pageInfo?.hasNextPage);
    },
    endCursor() {
      return this.rawEpics.pageInfo?.endCursor || '';
    },
    showFilteredSearchbar() {
      if (this.epicsFetchResultEmpty) {
        return this.hasFiltersApplied;
      }
      return true;
    },
    timeframeStart() {
      return this.timeframe[0];
    },
    timeframeEnd() {
      const last = this.timeframe.length - 1;
      return this.timeframe[last];
    },
  },
  methods: {
    toggleSettings() {
      this.isSettingsSidebarOpen = !this.isSettingsSidebarOpen;
    },
    async fetchNextPage() {
      if (this.hasNextPage && !this.epicsFetchNextPageInProgress) {
        this.epicsFetchNextPageInProgress = true;

        try {
          await this.$apollo.queries.rawEpics.fetchMore({
            variables: {
              endCursor: this.endCursor,
            },
          });
        } catch {
          this.epicsFetchFailure = true;
          createAlert({
            message: this.$options.epicsFetchError,
          });
        }
        this.epicsFetchNextPageInProgress = false;
      }
    },
  },
};
</script>

<template>
  <div class="roadmap-app-container gl-h-full">
    <roadmap-filters
      ref="roadmapFilters"
      :view-only="!showFilteredSearchbar || Boolean(epicIid)"
      @toggle-settings="toggleSettings"
    />
    <div
      :class="{ 'overflow-reset': epicsFetchResultEmpty }"
      class="roadmap-container gl-relative gl-rounded-b-base"
    >
      <gl-loading-icon v-if="epicsFetchInProgress" class="gl-my-5" size="lg" />
      <epics-list-empty
        v-else-if="epicsFetchResultEmpty"
        :preset-type="presetType"
        :timeframe-start="timeframeStart"
        :timeframe-end="timeframeEnd"
        :has-filters-applied="hasFiltersApplied"
        :filter-params="filterParams"
      />
      <roadmap-shell
        v-else-if="!epicsFetchFailure"
        :epics="epics"
        :epics-fetch-next-page-in-progress="epicsFetchNextPageInProgress"
        :has-next-page="hasNextPage"
        :is-settings-sidebar-open="isSettingsSidebarOpen"
        @scrolled-to-end="fetchNextPage"
      />
    </div>
    <roadmap-settings
      :is-open="isSettingsSidebarOpen"
      :timeframe-range-type="timeframeRangeType"
      data-testid="roadmap-settings"
      @toggle-settings="toggleSettings"
    />
  </div>
</template>
