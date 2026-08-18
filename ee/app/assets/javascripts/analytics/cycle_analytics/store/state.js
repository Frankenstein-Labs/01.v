import {
  PAGINATION_SORT_FIELD_DURATION,
  PAGINATION_SORT_DIRECTION_DESC,
} from '~/analytics/cycle_analytics/constants';

export default () => ({
  createdAfter: null,
  createdBefore: null,
  predefinedDateRange: null,

  isLoading: false,
  isLoadingStage: false,

  errorCode: null,

  groupPath: null,
  selectedProjects: [],
  selectedStage: null,
  selectedValueStream: null,
  namespace: { name: null, path: null, restApiRequestPath: null, type: null },

  selectedStageEvents: [],

  isLoadingValueStreams: false,
  isDeletingValueStream: false,
  isFetchingGroupStages: false,

  deleteValueStreamError: null,

  stages: [],
  selectedStageError: '',
  summary: [],
  medians: {},
  valueStreams: [],

  pagination: {
    page: null,
    hasNextPage: false,
    sort: PAGINATION_SORT_FIELD_DURATION,
    direction: PAGINATION_SORT_DIRECTION_DESC,
  },
  stageCounts: {},
  aggregation: {
    enabled: false,
    lastRunAt: null,
    nextRunAt: null,
  },
  canEdit: false,
  canReadCycleAnalytics: false,
  enableVsdLink: false,
  enableCustomizableStages: false,
  enableProjectsFilter: false,
});
