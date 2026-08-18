import { DATA_VIZ_BLUE_500, DATA_VIZ_ORANGE_600 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { uniq } from 'lodash-es';
import valueStreamAnalyticsStages from 'test_fixtures/analytics/value_stream_analytics/stages.json';
import tasksByType from 'test_fixtures/analytics/charts/type_of_work/tasks_by_type.json';
import apiGroupLabels from 'test_fixtures/api/group_labels.json';

import issueStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/issue/records.json';
import planStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/plan/records.json';
import reviewStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/review/records.json';
import codeStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/code/records.json';
import testStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/test/records.json';
import stagingStageFixtures from 'test_fixtures/analytics/value_stream_analytics/stages/staging/records.json';

import issueCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/issue/count.json';
import planCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/plan/count.json';
import reviewCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/review/count.json';
import codeCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/code/count.json';
import testCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/test/count.json';
import stagingCountFixture from 'test_fixtures/analytics/value_stream_analytics/stages/staging/count.json';

import {
  OVERVIEW_STAGE_CONFIG,
  DURATION_CHART_Y_AXIS_TITLE,
} from 'ee/analytics/cycle_analytics/constants';
import {
  STACKED_AREA_CHART_SERIES_OPTIONS,
  STACKED_AREA_CHART_NULL_SERIES_OPTIONS,
} from 'ee/analytics/shared/constants';
import * as types from 'ee/analytics/cycle_analytics/store/mutation_types';
import mutations from 'ee/analytics/cycle_analytics/store/mutations';
import { transformRawTasksByTypeData } from 'ee/analytics/cycle_analytics/utils';
import {
  getStageByTitle,
  rawStageMedians,
  createdBefore,
  createdAfter,
  deepCamelCase,
} from 'jest/analytics/cycle_analytics/mock_data';
import { toYmd } from '~/analytics/shared/utils';
import {
  transformStagesForPathNavigation,
  formatMedianValues,
} from '~/analytics/cycle_analytics/utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getDatesInRange } from '~/lib/utils/datetime_utility';

export const endpoints = {
  durationData:
    /analytics\/value_stream_analytics\/value_streams\/\w+\/stages\/\w+\/average_duration_chart/,
  stageData: /analytics\/value_stream_analytics\/value_streams\/\w+\/stages\/\w+\/records/,
  stageMedian: /analytics\/value_stream_analytics\/value_streams\/\w+\/stages\/\w+\/median/,
  stageCount: /analytics\/value_stream_analytics\/value_streams\/\w+\/stages\/\w+\/count/,
  baseStagesEndpoint: /analytics\/value_stream_analytics\/value_streams\/\w+\/stages$/,
  tasksByTypeData: /analytics\/type_of_work\/tasks_by_type/,
  tasksByTypeTopLabelsData: /analytics\/type_of_work\/tasks_by_type\/top_labels/,
  valueStreamData: /analytics\/value_stream_analytics\/value_streams/,
};

export const valueStreams = [
  { id: 1, name: 'Value stream 1' },
  { id: 2, name: 'Value stream 2' },
];

export const vsaPath = '/analytics/value_stream_analytics';
export const valueStreamPath = `${vsaPath}?value_stream_id=${valueStreams[0].id}`;
export const newValueStreamPath = `${vsaPath}/value_streams/new`;
export const editValueStreamPath = `${vsaPath}/value_streams/:id/edit`;

export const groupLabels = apiGroupLabels.map((l) =>
  convertObjectPropsToCamelCase({ ...l, title: l.name }),
);
export const groupLabelNames = groupLabels.map(({ title }) => title);

export const customizableStagesAndEvents = valueStreamAnalyticsStages;

const dummyState = {};

// prepare the raw stage data for our components
mutations[types.RECEIVE_GROUP_STAGES_SUCCESS](dummyState, customizableStagesAndEvents.stages);

export const issueStage = getStageByTitle(dummyState.stages, 'issue');
export const planStage = getStageByTitle(dummyState.stages, 'plan');
export const reviewStage = getStageByTitle(dummyState.stages, 'review');
export const codeStage = getStageByTitle(dummyState.stages, 'code');
export const testStage = getStageByTitle(dummyState.stages, 'test');
export const stagingStage = getStageByTitle(dummyState.stages, 'staging');

export const allowedStages = [issueStage, planStage, codeStage];

const stageFixtures = {
  issue: issueStageFixtures,
  plan: planStageFixtures,
  review: reviewStageFixtures,
  code: codeStageFixtures,
  test: testStageFixtures,
  staging: stagingStageFixtures,
};

const getStageId = (name) => {
  const { id } = getStageByTitle(dummyState.stages, name);
  return id;
};

export const stageMediansWithNumericIds = formatMedianValues(
  rawStageMedians.map(({ id: name, ...rest }) => {
    const id = getStageId(name);
    return { ...rest, name, id };
  }),
);

export const rawStageCounts = [
  {
    id: 'issue',
    ...issueCountFixture,
  },
  {
    id: 'plan',
    ...planCountFixture,
  },
  {
    id: 'review',
    ...reviewCountFixture,
  },
  {
    id: 'code',
    ...codeCountFixture,
  },
  {
    id: 'test',
    ...testCountFixture,
  },
  {
    id: 'staging',
    ...stagingCountFixture,
  },
];

export const stageCounts = rawStageCounts.reduce((acc, { id: name, count }) => {
  const id = getStageId(name);
  return {
    ...acc,
    [id]: count,
  };
}, {});

export const issueEvents = deepCamelCase(stageFixtures.issue);
export const reviewEvents = deepCamelCase(stageFixtures.review);
export const testEvents = deepCamelCase(stageFixtures.test);
export const stagingEvents = deepCamelCase(stageFixtures.staging);
export const rawCustomStage = {
  name: 'Coolest beans stage',
  title: 'Coolest beans stage',
  hidden: false,
  legend: 'Cool legend',
  description: 'Time before an issue gets scheduled',
  id: 18,
  custom: true,
  start_event_identifier: 'issue_first_mentioned_in_commit',
  end_event_identifier: 'issue_first_added_to_board',
};

export const medians = stageMediansWithNumericIds;

export const rawCustomStageEvents = customizableStagesAndEvents.events;
export const camelCasedStageEvents = rawCustomStageEvents.map(deepCamelCase);

export const customStageLabelEvents = camelCasedStageEvents.filter((ev) => ev.type === 'label');
export const customStageStartEvents = camelCasedStageEvents.filter((ev) => ev.canBeStartEvent);

// get all the possible end events
const allowedEndEventIds = new Set(customStageStartEvents.flatMap((e) => e.allowedEndEvents));
export const customStageEndEvents = camelCasedStageEvents.filter((ev) =>
  allowedEndEventIds.has(ev.identifier),
);

export const customStageEvents = uniq(
  [...customStageStartEvents, ...customStageEndEvents],
  false,
  (ev) => ev.identifier,
);

export const labelStartEvent = customStageLabelEvents[0];
export const labelEndEvent = customStageLabelEvents.find(
  (ev) => ev.identifier === labelStartEvent.allowedEndEvents[0],
);

const dateRange = getDatesInRange(createdAfter, createdBefore, toYmd);

export const apiTasksByTypeData = tasksByType.map((labelData) => {
  // add data points for our mock date range
  const maxValue = 10;
  const series = dateRange.map((date) => [date, Math.floor(Math.random() * Math.floor(maxValue))]);
  return {
    ...labelData,
    series,
  };
});

export const rawTasksByTypeData = transformRawTasksByTypeData(apiTasksByTypeData);

export const transformedStagePathData = transformStagesForPathNavigation({
  stages: [{ ...OVERVIEW_STAGE_CONFIG }, ...allowedStages],
  medians,
  stageCounts,
  selectedStage: issueStage,
});

export const tasksByTypeData = {
  seriesNames: ['Cool label', 'Normal label'],
  data: [
    [0, 1, 2],
    [5, 2, 3],
    [2, 4, 1],
  ],
  groupBy: ['Group 1', 'Group 2', 'Group 3'],
};

export const currentGroup = {
  id: 22,
  name: 'Gitlab Org',
  fullName: 'Gitlab Org',
  fullPath: 'gitlab-org',
};

export const transformedDurationData = [
  {
    id: issueStage.id,
    name: 'Issue',
    selected: true,
    data: [
      {
        average_duration_in_seconds: 1134000, // ~13 days
        date: '2019-01-01T00:00:00.000Z',
      },
      {
        average_duration_in_seconds: 2321000, // ~27 days
        date: '2019-01-02T00:00:00.000Z',
      },
    ],
  },
  {
    id: planStage.id,
    name: 'Plan',
    selected: true,
    data: [
      {
        average_duration_in_seconds: 2142000, // ~25 days
        date: '2019-01-01T00:00:00.000Z',
      },
      {
        average_duration_in_seconds: 3635000, // ~42 days
        date: '2019-01-02T00:00:00.000Z',
      },
    ],
  },
  {
    id: codeStage.id,
    name: 'Code',
    selected: true,
    data: [
      {
        average_duration_in_seconds: 1234000, // ~14 days
        date: '2019-01-01T00:00:00.000Z',
      },
      {
        average_duration_in_seconds: 4321000, // ~50 days
        date: '2019-01-02T00:00:00.000Z',
      },
    ],
  },
];

export const flattenedDurationData = [
  { average_duration_in_seconds: 1134000, date: '2019-01-01' },
  { average_duration_in_seconds: 2321000, date: '2019-01-02' },
  { average_duration_in_seconds: 2142000, date: '2019-01-01' },
  { average_duration_in_seconds: 3635000, date: '2019-01-02' },
  { average_duration_in_seconds: 1234000, date: '2019-01-01' },
  { average_duration_in_seconds: 4321000, date: '2019-01-02' },
];

export const durationChartPlottableData = [
  ['2019-01-01', 1503333.3333333333],
  ['2019-01-02', 3425666.6666666665],
];

export const pathNavIssueMetric = 172800;

export const aggregationData = {
  enabled: true,
  lastRunAt: '2022-03-11T04:34:59Z',
  nextRunAt: '2022-03-11T05:21:01Z',
};

export const durationDataSeries = {
  areaStyle: {
    opacity: 0,
  },
  data: durationChartPlottableData,
  name: DURATION_CHART_Y_AXIS_TITLE,
  itemStyle: { color: '#617ae2' },
  lineStyle: {
    color: DATA_VIZ_BLUE_500,
  },
  showSymbol: true,
};

export const durationDataNullSeries = {
  areaStyle: {
    color: 'none',
  },
  data: [
    ['2019-01-01', null],
    ['2019-01-02', null],
  ],
  itemStyle: {
    color: '#a4a3a8',
  },
  lineStyle: {
    color: '#a4a3a8',
    type: 'dashed',
  },
  name: `${DURATION_CHART_Y_AXIS_TITLE} no data series`,
  showSymbol: false,
};

export const durationOverviewChartPlottableData = [
  {
    name: 'Issue',
    data: [
      ['2019-01-01', 1134000],
      ['2019-01-02', 2321000],
    ],
  },
  {
    name: 'Plan',
    data: [
      ['2019-01-01', 2142000],
      ['2019-01-02', 3635000],
    ],
  },
];

export const durationOverviewChartOptionsData = durationOverviewChartPlottableData.map(
  (stageDetails) => ({
    ...stageDetails,
    ...STACKED_AREA_CHART_SERIES_OPTIONS,
  }),
);

export const durationOverviewDataSeries = durationOverviewChartPlottableData.map(
  (stageDetails, idx) => {
    const colors = [DATA_VIZ_BLUE_500, DATA_VIZ_ORANGE_600];

    return {
      ...stageDetails,
      lineStyle: {
        color: colors[idx],
        type: 'solid',
      },
    };
  },
);

export const durationOverviewDataNullSeries = durationOverviewChartPlottableData.map(
  ({ name }) => ({
    areaStyle: {
      color: 'none',
    },
    data: [
      ['2019-01-01', null],
      ['2019-01-02', null],
    ],
    itemStyle: {
      color: '#a4a3a8',
    },
    lineStyle: {
      color: '#a4a3a8',
      type: 'dashed',
    },
    name,
    showSymbol: false,
    ...STACKED_AREA_CHART_NULL_SERIES_OPTIONS,
  }),
);

export const durationOverviewLegendSeriesInfo = durationOverviewDataSeries.map(
  ({ name, lineStyle }) => ({
    name,
    ...lineStyle,
  }),
);

export const averageDurationsStageData = [
  {
    id: 'gid://gitlab/Analytics::CycleAnalytics::Stage/1',
    name: 'issue',
    metrics: {
      series: {
        averageDurations: [
          { date: '2019-01-02', value: 1032202 },
          { date: '2019-01-03', value: 1295998 },
          { date: '2019-01-04', value: 552478 },
        ],
      },
    },
  },
  {
    id: 'gid://gitlab/Analytics::CycleAnalytics::Stage/2',
    name: 'plan',
    metrics: {
      series: {
        averageDurations: [
          { date: '2019-01-01', value: 54760 },
          { date: '2019-01-02', value: 340918 },
          { date: '2019-01-06', value: 237218 },
        ],
      },
    },
  },
  {
    id: 'gid://gitlab/Analytics::CycleAnalytics::Stage/3',
    name: 'review',
    metrics: {
      series: {
        averageDurations: [
          { date: '2019-01-02', value: 340918 },
          { date: '2019-01-05', value: 54760 },
          { date: '2019-01-08', value: 16416 },
          { date: '2019-01-09', value: 237218 },
        ],
      },
    },
  },
];

export const averageDurationsStageQueryResponses = averageDurationsStageData.map((stage) => ({
  data: {
    project: null,
    group: {
      id: 'gid://gitlab/Group/33',
      valueStreams: {
        nodes: [
          {
            __typename: 'ValueStream',
            stages: [stage],
          },
        ],
        __typename: 'ValueStreamConnection',
      },
    },
  },
}));
