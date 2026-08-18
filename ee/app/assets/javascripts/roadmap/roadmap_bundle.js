import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { queryToObject } from '~/lib/utils/url_utility';
import Translate from '~/vue_shared/translate';

import RoadmapApp from './components/roadmap_app.vue';
import localRoadmapSettingsQuery from './queries/local_roadmap_settings.query.graphql';
import { defaultClient } from './graphql';
import {
  DATE_RANGES,
  PROGRESS_WEIGHT,
  UNSUPPORTED_ROADMAP_PARAMS,
  MILESTONES_ALL,
  ALLOWED_SORT_VALUES,
} from './constants';

import {
  getPresetTypeForTimeframeRangeType,
  getTimeframeForRangeType,
} from './utils/roadmap_utils';

Vue.use(Translate);
Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-roadmap');

  if (!el) {
    return false;
  }

  const { dataset } = el;

  const rawFilterParams = queryToObject(window.location.search, {
    gatherArrays: true,
  });

  const filterParams = {
    ...convertObjectPropsToCamelCase(rawFilterParams, {
      dropKeys: UNSUPPORTED_ROADMAP_PARAMS,
    }),
    // We shall put parsed value of `confidential` only
    // when it is defined.
    ...(rawFilterParams.confidential && {
      confidential: parseBoolean(rawFilterParams.confidential),
    }),

    ...(rawFilterParams.epicIid && {
      epicIid: rawFilterParams.epicIid,
    }),
  };

  const timeframeRangeType =
    Object.keys(DATE_RANGES).indexOf(dataset.timeframeRangeType) > -1
      ? dataset.timeframeRangeType
      : DATE_RANGES.CURRENT_QUARTER;
  const presetType = getPresetTypeForTimeframeRangeType(timeframeRangeType, dataset.presetType);
  const timeframe = getTimeframeForRangeType({
    timeframeRangeType,
    presetType,
  });

  defaultClient.cache.writeQuery({
    query: localRoadmapSettingsQuery,
    data: {
      localRoadmapSettings: {
        __typename: 'LocalRoadmapSettings',
        filterParams,
        sortedBy: ALLOWED_SORT_VALUES.includes(dataset.sortedBy)
          ? dataset.sortedBy
          : ALLOWED_SORT_VALUES[0],
        bufferSize: 0,
        epicsState: dataset.epicsState,
        timeframe,
        timeframeRangeType,
        progressTracking: rawFilterParams.progress || PROGRESS_WEIGHT,
        milestonesType: rawFilterParams.milestones_type || MILESTONES_ALL,
        isShowingMilestones:
          rawFilterParams.show_milestones === undefined
            ? true
            : parseBoolean(rawFilterParams.show_milestones),
        isShowingLabels: rawFilterParams.show_labels
          ? parseBoolean(rawFilterParams.show_labels)
          : false,
        presetType,
        isProgressTrackingActive:
          rawFilterParams.show_progress === undefined
            ? true
            : parseBoolean(rawFilterParams.show_progress),
      },
    },
  });

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  return initVueApp({
    el,
    name: 'RoadmapRoot',
    apolloProvider,
    component: RoadmapApp,
    provide() {
      return {
        newEpicPath: dataset.newEpicPath,
        listEpicsPath: dataset.listEpicsPath,
        epicsDocsPath: dataset.epicsDocsPath,
        groupFullPath: dataset.fullPath,
        groupMilestonesPath: dataset.groupMilestonesEndpoint,
        canCreateEpic: parseBoolean(dataset.canCreateEpic),
        emptyStateIllustrationPath: dataset.emptyStateIllustration,
        fullPath: dataset.fullPath,
        epicIid: dataset.iid,
        allowSubEpics: parseBoolean(dataset.allowSubEpics),
        allowScopedLabels: dataset.allowScopedLabels,
        hasScopedLabelsFeature: dataset.allowScopedLabels,
        isChildEpics: parseBoolean(dataset.childEpics),
        currentGroupId: parseInt(dataset.groupId, 10),
      };
    },
  });
};
