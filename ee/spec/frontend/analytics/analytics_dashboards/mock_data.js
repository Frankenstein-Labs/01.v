import { TEST_HOST } from 'spec/test_constants';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNEE,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TITLE_SOURCE_BRANCH,
  TOKEN_TITLE_TARGET_BRANCH,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
} from '~/vue_shared/components/filtered_search_bar/constants';
import MilestoneToken from '~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';
import UserToken from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';
import { FILTERED_SEARCH_MAX_LABELS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { NULL_SERIES_ID } from 'ee/analytics/shared/constants';
import { VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE } from 'ee/analytics/analytics_dashboards/constants';
import { getUniquePanelId } from '~/explore/analytics_dashboards/utils';
import BranchToken from '~/vue_shared/components/filtered_search_bar/tokens/branch_token.vue';

export const TEST_TRACKING_KEY = 'gid://gitlab/Project/2';

export const TEST_COLLECTOR_HOST = TEST_HOST;

export const TEST_ROUTER_BACK_HREF = 'go-back';

export const TEST_CUSTOM_DASHBOARDS_GROUP = {
  fullPath: 'test-namespace',
  id: 12,
  name: 'test-dashboards-namespace',
};

export const TEST_CUSTOM_DASHBOARDS_PROJECT = {
  fullPath: 'test/test-dashboards',
  id: 123,
  name: 'test-dashboards',
  defaultBranch: 'some-branch',
};

export const getGraphQLDashboard = (options = {}) => ({
  slug: '',
  title: '',
  userDefined: false,
  status: null,
  gridHeight: 'DEFAULT',
  description: 'Understand your audience',
  __typename: 'CustomizableDashboard',
  errors: [],
  filters: {},
  ...options,
});

export const getGraphQLDashboardWithPanels = (options = {}) => ({
  ...getGraphQLDashboard(options),
  panels: {
    nodes: [
      {
        title: 'Daily Active Users',
        titleIcon: 'chart',
        tooltip: {
          description: `Number of unique users per day. %{linkStart}Learn more%{linkEnd}`,
          descriptionLink: 'https://gitlab.com',
        },
        gridAttributes: {
          yPos: 1,
          xPos: 0,
          width: 6,
          height: 5,
        },
        queryOverrides: {
          limit: 200,
        },
        visualization: {
          slug: 'line_chart',
          type: 'LineChart',
          options: {
            xAxis: {
              name: 'Time',
              type: 'time',
            },
            yAxis: {
              name: 'Counts',
              type: 'time',
            },
          },
          data: {
            type: 'cube_analytics',
            query: {
              measures: ['TrackedEvents.uniqueUsersCount'],
              timeDimensions: [
                {
                  dimension: 'TrackedEvents.derivedTstamp',
                  granularity: 'day',
                },
              ],
              limit: 100,
              timezone: 'UTC',
              filters: [],
              dimensions: [],
            },
          },
          errors: null,
          __typename: 'CustomizableDashboardVisualization',
        },
        views: [],
        __typename: 'CustomizableDashboardPanel',
      },
    ],
    __typename: 'CustomizableDashboardPanelConnection',
  },
});

export const TEST_DASHBOARD_GRAPHQL_404_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const TEST_AUDIENCE_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [getGraphQLDashboardWithPanels({ slug: 'audience', title: 'Audience' })],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboardWithPanels({
            slug: 'value_streams_dashboard',
            title: 'Value Streams Dashboard',
            userDefined: false,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: null,
    group: {
      id: 'gid://gitlab/Group/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'value_streams_dashboard',
            title: 'Value Streams Dashboard',
            userDefined: false,
            panels: [],
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Group',
    },
  },
};

export const TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboardWithPanels({
            slug: 'duo_and_sdlc_trends',
            title: 'GitLab Duo and SDLC trends',
            userDefined: false,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

const mockUsageOverviewPanel = {
  __typename: 'CustomizableDashboardPanel',
  title: 'Usage overview',
  titleIcon: null,
  tooltip: null,
  gridAttributes: { yPos: 0, xPos: 0, width: 12, height: 1 },
  queryOverrides: null,
  visualization: {
    __typename: 'CustomizableDashboardVisualization',
    slug: 'usage_overview',
    type: 'UsageOverview',
    options: {},
    data: {
      type: 'usage_overview',
      query: { include: ['groups', 'projects', 'issues', 'merge_requests', 'pipelines'] },
    },
    errors: null,
  },
  views: [],
};

const mockUsageCountPanel = {
  __typename: 'CustomizableDashboardPanel',
  title: 'Issues',
  titleIcon: null,
  tooltip: null,
  gridAttributes: { yPos: 1, xPos: 0, width: 4, height: 4 },
  queryOverrides: null,
  visualization: {
    __typename: 'CustomizableDashboardVisualization',
    slug: 'issues_count',
    type: 'SingleStat',
    options: {},
    data: {
      type: 'usage_count',
      query: { metric: 'issues' },
    },
    errors: null,
  },
  views: [],
};

const usageDashboardResponse = (panel) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'value_streams_dashboard',
            title: 'Value Streams Dashboard',
            userDefined: false,
            panels: {
              nodes: [panel],
              __typename: 'CustomizableDashboardPanelConnection',
            },
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
});

export const TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE =
  usageDashboardResponse(mockUsageOverviewPanel);

export const TEST_DASHBOARD_WITH_USAGE_COUNT_GRAPHQL_SUCCESS_RESPONSE =
  usageDashboardResponse(mockUsageCountPanel);

export const mockInvalidDashboardErrors = [
  'root is missing required keys: version',
  "property '/panels/0' is missing required keys: queryOverrides",
  "property '/panels/0/id' is invalid: error_type=schema",
  "property '/panels/1' is missing required keys: queryOverrides",
  "property '/panels/1/id' is invalid: error_type=schema",
  "property '/panels/2' is missing required keys: queryOverrides",
  "property '/panels/2/id' is invalid: error_type=schema",
];

export const TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboardWithPanels({
            slug: 'custom_dashboard',
            title: 'Custom Dashboard',
            userDefined: true,
            errors: mockInvalidDashboardErrors,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const createGroupDashboardGraphqlSuccessResponse = (dashboardNodes) => ({
  data: {
    project: null,
    group: {
      id: 'gid://gitlab/Group/1',
      customizableDashboards: {
        nodes: [dashboardNodes],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Group',
    },
  },
});

export const createDashboardGraphqlSuccessResponse = (dashboardNodes) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [dashboardNodes],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
});

export const mockResultSet = {
  seriesNames: () => [
    {
      title: 'pageview, TrackedEvents Count',
      key: 'pageview,TrackedEvents.count',
      yValues: ['pageview', 'TrackedEvents.count'],
    },
  ],
  chartPivot: () => [
    {
      x: '2022-11-09T00:00:00.000',
      xValues: ['2022-11-09T00:00:00.000'],
      'pageview,TrackedEvents.count': 55,
    },
    {
      x: '2022-11-10T00:00:00.000',
      xValues: ['2022-11-10T00:00:00.000'],
      'pageview,TrackedEvents.count': 14,
    },
  ],
  tableColumns: () => [
    {
      key: 'TrackedEvents.utcTime.day',
      title: 'TrackedEvents Utc Time',
      shortTitle: 'Utc Time',
      type: 'time',
      dataIndex: 'TrackedEvents.utcTime.day',
    },
    {
      key: 'TrackedEvents.eventType',
      title: 'TrackedEvents Event Type',
      shortTitle: 'Event Type',
      type: 'string',
      dataIndex: 'TrackedEvents.eventType',
    },
    {
      key: 'TrackedEvents.count',
      type: 'number',
      dataIndex: 'TrackedEvents.count',
      title: 'TrackedEvents Count',
      shortTitle: 'Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.utcTime.day': '2022-11-09T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '55',
    },
    {
      'TrackedEvents.utcTime.day': '2022-11-10T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '14',
    },
  ],
  rawData: () => [
    {
      'TrackedEvents.userLanguage': 'en-US',
      'TrackedEvents.count': '36',
      'TrackedEvents.url': 'https://example.com/us',
    },
    {
      'TrackedEvents.userLanguage': 'es-ES',
      'TrackedEvents.count': '60',
      'TrackedEvents.url': 'https://example.com/es',
    },
  ],
};

export const mockTableWithLinksResultSet = {
  tableColumns: () => [
    {
      key: 'TrackedEvents.docPath',
      title: 'Tracked Events Doc Path',
      shortTitle: 'Doc Path',
      type: 'string',
      dataIndex: 'TrackedEvents.docPath',
    },
    {
      key: 'TrackedEvents.url',
      title: 'Tracked Events Url',
      shortTitle: 'Url',
      type: 'string',
      dataIndex: 'TrackedEvents.url',
    },
    {
      key: 'TrackedEvents.pageViewsCount',
      type: 'number',
      dataIndex: 'TrackedEvents.pageViewsCount',
      title: 'Tracked Events Page Views Count',
      shortTitle: 'Page Views Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.docPath': '/foo',
      'TrackedEvents.url': 'https://example.com/foo',
      'TrackedEvents.pageViewsCount': '1',
    },
  ],
};

export const mockResultSetWithNullValues = {
  rawData: () => [
    {
      'TrackedEvents.userLanguage': null,
      'TrackedEvents.count': null,
      'TrackedEvents.url': null,
    },
  ],
};

export const mockContinueWaitProgressResult = {
  progressResponse: {
    error: 'Continue wait',
  },
};

export const mockFilters = {
  startDate: new Date('2015-01-01'),
  endDate: new Date('2016-01-01'),
};

export const mockMetaData = {
  cubes: [
    {
      name: 'Sessions',
      type: 'cube',
      title: 'Sessions',
      isVisible: true,
      public: true,
      measures: [
        {
          name: 'Sessions.count',
          title: 'Sessions Count',
          shortTitle: 'Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
        {
          name: 'Sessions.averagePerUser',
          title: 'Sessions Average Per User',
          shortTitle: 'Average Per User',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'number',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
      ],
      dimensions: [
        {
          name: 'Sessions.sessionID',
          title: 'Sessions Session Id',
          type: 'string',
          shortTitle: 'Session Id',
          suggestFilterValues: true,
          isVisible: false,
          public: false,
          primaryKey: true,
        },
        {
          name: 'Sessions.startAt',
          title: 'Sessions Start at',
          type: 'time',
          shortTitle: 'Start at',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'Sessions.endAt',
          title: 'Sessions End at',
          type: 'time',
          shortTitle: 'End at',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
      ],
      segments: [],
      hierarchies: [],
    },
    {
      name: 'TrackedEvents',
      type: 'cube',
      title: 'Tracked Events',
      isVisible: true,
      public: true,
      measures: [
        {
          name: 'TrackedEvents.pageViewsCount',
          title: 'Tracked Events Page Views Count',
          shortTitle: 'Page Views Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: [],
          drillMembersGrouped: {
            measures: [],
            dimensions: [],
          },
          isVisible: true,
          public: true,
        },
        {
          name: 'TrackedEvents.count',
          title: 'Tracked Events Count',
          shortTitle: 'Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
          drillMembersGrouped: {
            measures: [],
            dimensions: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
          },
          isVisible: true,
        },
      ],
      dimensions: [
        {
          name: 'TrackedEvents.pageTitle',
          title: 'Tracked Events Page Title',
          type: 'string',
          shortTitle: 'Page Title',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'TrackedEvents.pageUrl',
          title: 'Tracked Events Page Url',
          type: 'string',
          shortTitle: 'Page Url',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
        {
          name: 'TrackedEvents.derivedTstamp',
          title: 'Tracked Events Derived Tstamp',
          type: 'time',
          shortTitle: 'Derived Tstamp',
          suggestFilterValues: true,
          isVisible: true,
          public: true,
          primaryKey: false,
        },
      ],
      segments: [
        {
          name: 'TrackedEvents.knownUsers',
          title: 'Tracked Events Known Users',
          shortTitle: 'Known Users',
          isVisible: true,
          public: true,
        },
      ],
      hierarchies: [],
    },
  ],
};

export const mockFilterOptions = {
  availableMeasures: [
    {
      name: 'Sessions.count',
      title: 'Sessions Count',
      shortTitle: 'Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'Sessions.averagePerUser',
      title: 'Sessions Average Per User',
      shortTitle: 'Average Per User',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'number',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'TrackedEvents.pageViewsCount',
      title: 'Tracked Events Page Views Count',
      shortTitle: 'Page Views Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: [],
      drillMembersGrouped: {
        measures: [],
        dimensions: [],
      },
      isVisible: true,
      public: true,
    },
    {
      name: 'TrackedEvents.count',
      title: 'Tracked Events Count',
      shortTitle: 'Count',
      cumulativeTotal: false,
      cumulative: false,
      type: 'number',
      aggType: 'count',
      drillMembers: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
      drillMembersGrouped: {
        measures: [],
        dimensions: ['TrackedEvents.eventId', 'TrackedEvents.pageTitle'],
      },
      isVisible: true,
    },
  ],
  availableDimensions: [
    {
      name: 'Sessions.sessionID',
      title: 'Sessions Session Id',
      type: 'string',
      shortTitle: 'Session Id',
      suggestFilterValues: true,
      isVisible: false,
      public: false,
      primaryKey: true,
    },
    {
      name: 'TrackedEvents.pageTitle',
      title: 'Tracked Events Page Title',
      type: 'string',
      shortTitle: 'Page Title',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'TrackedEvents.pageUrl',
      title: 'Tracked Events Page Url',
      type: 'string',
      shortTitle: 'Page Url',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
  ],
  availableTimeDimensions: [
    {
      name: 'Sessions.startAt',
      title: 'Sessions Start at',
      type: 'time',
      shortTitle: 'Start at',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'Sessions.endAt',
      title: 'Sessions End at',
      type: 'time',
      shortTitle: 'End at',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
    {
      name: 'TrackedEvents.derivedTstamp',
      title: 'Tracked Events Derived Tstamp',
      type: 'time',
      shortTitle: 'Derived Tstamp',
      suggestFilterValues: true,
      isVisible: true,
      public: true,
      primaryKey: false,
    },
  ],
};

export const mockGroupUsageMetricsQueryResponse = {
  group: {
    id: 'gid://gitlab/Group/225',
    fullName: 'GitLab Org',
    avatarUrl: '/avatar.png',
    visibility: 'public',
    __typename: 'Group',
    groups: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'GROUPS',
      count: 58,
      recordedAt: '2023-11-27T23:59:59Z',
    },
    projects: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PROJECTS',
      count: 97,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    users: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'USERS',
      count: 90,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    issues: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'ISSUES',
      count: 123,
      recordedAt: '2023-11-26T23:59:59Z',
    },
    pipelines: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PIPELINES',
      count: 123,
      recordedAt: undefined,
    },
    merge_requests: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'MERGE_REQUESTS',
      count: 183,
      recordedAt: '2022-11-27T23:59:59Z',
    },
  },
  project: null,
};

export const mockGroupUsageMetricsZeroQueryResponse = {
  group: {
    id: 'gid://gitlab/Group/225',
    fullName: 'GitLab Org',
    avatarUrl: '/avatar.png',
    visibility: 'public',
    __typename: 'Group',
    groups: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'GROUPS',
      count: 0,
      recordedAt: '2023-11-27T23:59:59Z',
    },
    projects: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PROJECTS',
      count: 0,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    users: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'USERS',
      count: 0,
      recordedAt: '2023-11-27T21:59:59Z',
    },
    issues: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'ISSUES',
      count: 0,
      recordedAt: '2023-11-26T23:59:59Z',
    },
    pipelines: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PIPELINES',
      count: 0,
      recordedAt: undefined,
    },
    merge_requests: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'MERGE_REQUESTS',
      count: 0,
      recordedAt: '2022-11-27T23:59:59Z',
    },
  },
  project: null,
};

export const mockProjectUsageMetricsQueryResponse = {
  group: null,
  project: {
    id: 'gid://gitlab/Project/7',
    nameWithNamespace: 'GitLab Org / GitLab',
    avatarUrl: '/avatar.png',
    visibility: 'internal',
    __typename: 'Project',
    issues: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'ISSUES',
      count: 133,
      recordedAt: '2023-11-26T23:59:59Z',
    },
    pipelines: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'PIPELINES',
      count: 150,
      recordedAt: undefined,
    },
    merge_requests: {
      __typename: 'ValueStreamDashboardCount',
      identifier: 'MERGE_REQUESTS',
      count: 200,
      recordedAt: '2022-11-27T23:59:59Z',
    },
  },
};

export const mockUsageGroupNamespaceData = {
  id: 225,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org',
  namespaceType: 'Group',
  visibilityLevelIcon: 'earth',
  visibilityLevelTooltip:
    'Public - The group and any public projects can be viewed without any authentication.',
};

export const mockUsageProjectNamespaceData = {
  id: 7,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org / GitLab',
  namespaceType: 'Project',
  visibilityLevelIcon: 'shield',
  visibilityLevelTooltip:
    'Internal - The project can be accessed by any logged in user except external users.',
};

export const mockGroupUsageMetrics = [
  {
    identifier: 'groups',
    value: 58,
    recordedAt: '2023-11-27T23:59:59Z',
    options: {
      title: 'Groups',
      metricIcon: 'group',
    },
  },
  {
    identifier: 'projects',
    value: 97,
    recordedAt: '2023-11-27T21:59:59Z',
    options: {
      title: 'Projects',
      metricIcon: 'project',
    },
  },
  {
    identifier: 'users',
    value: 90,
    recordedAt: '2023-11-27T21:59:59Z',
    options: {
      title: 'Users',
      metricIcon: 'user',
    },
  },
  {
    identifier: 'issues',
    value: 123,
    recordedAt: '2023-11-26T23:59:59Z',
    options: {
      title: 'Issues',
      metricIcon: 'work-item-issue',
    },
  },
  {
    identifier: 'merge_requests',
    value: 183,
    recordedAt: '2022-11-27T23:59:59Z',
    options: {
      title: 'Merge requests',
      metricIcon: 'merge-request',
    },
  },
  {
    identifier: 'pipelines',
    value: 123,
    recordedAt: undefined,
    options: {
      title: 'Pipelines',
      metricIcon: 'pipeline',
    },
  },
];

export const mockProjectUsageMetrics = [
  {
    identifier: 'issues',
    value: 133,
    recordedAt: '2023-11-26T23:59:59Z',
    options: {
      title: 'Issues',
      metricIcon: 'work-item-issue',
    },
  },
  {
    identifier: 'merge_requests',
    value: 200,
    recordedAt: '2022-11-27T23:59:59Z',
    options: {
      title: 'Merge requests',
      metricIcon: 'merge-request',
    },
  },
  {
    identifier: 'pipelines',
    value: 150,
    recordedAt: undefined,
    options: {
      title: 'Pipelines',
      metricIcon: 'pipeline',
    },
  },
];

export const mockUsageMetricsNoData = [
  {
    identifier: 'groups',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Groups', metricIcon: 'group' },
  },
  {
    identifier: 'projects',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Projects', metricIcon: 'project' },
  },
  {
    identifier: 'users',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Users', metricIcon: 'user' },
  },
  {
    identifier: 'issues',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Issues', metricIcon: 'work-item-issue' },
  },
  {
    identifier: 'merge_requests',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Merge requests', metricIcon: 'merge-request' },
  },
  {
    identifier: 'pipelines',
    value: 0,
    recordedAt: undefined,
    options: { title: 'Pipelines', metricIcon: 'pipeline' },
  },
];

export const mockGroupUsageOverviewData = {
  namespace: mockUsageGroupNamespaceData,
  metrics: mockGroupUsageMetrics,
};

export const mockProjectUsageOverviewData = {
  namespace: mockUsageProjectNamespaceData,
  metrics: mockProjectUsageMetrics,
};

export const invalidVisualization = {
  type: 'LineChart',
  slug: 'invalid_visualization',
  version: 23, // bad version
  titlePropertyTypoOhNo: 'Cube line chart', // bad property name
  data: {
    type: 'cube_analytics',
    query: {
      users: {
        measures: ['TrackedEvents.count'],
        dimensions: ['TrackedEvents.eventType'],
      },
    },
  },
  errors: [
    `property '/version' is not: 1`,
    `property '/titlePropertyTypoOhNo' is invalid: error_type=schema`,
  ],
};

export const licensedVisualization = {
  type: 'CoolLicensedVisualization',
  slug: VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE,
  version: 1,
  title: 'Licensed visualization',
  data: {
    type: 'cube_analytics',
    query: {
      users: {
        measures: ['TrackedEvents.count'],
        dimensions: ['TrackedEvents.eventType'],
      },
    },
  },
};

export const mockPanel = {
  ...getGraphQLDashboardWithPanels({ slug: 'behavior', title: 'Behavior' }).panels.nodes[0],
  id: getUniquePanelId(),
};

export const TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboard({ slug: 'audience', title: 'Audience' }),
          getGraphQLDashboard({ slug: 'behavior', title: 'Behavior' }),
          getGraphQLDashboard({ slug: 'new_dashboard', title: 'new_dashboard', userDefined: true }),
          getGraphQLDashboard({
            slug: 'audience_copy',
            title: 'Audience (Copy)',
            userDefined: true,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [getGraphQLDashboardWithPanels({ slug: 'audience', title: 'Audience' })],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
    group: null,
  },
};

export const TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      customizableDashboards: {
        nodes: [
          getGraphQLDashboardWithPanels({
            slug: 'custom_dashboard',
            title: 'Custom Dashboard',
            userDefined: true,
          }),
        ],
        __typename: 'CustomizableDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/73',
      customizableDashboardVisualizations: {
        nodes: [
          {
            slug: 'another_one',
            type: 'SingleStat',
            data: {
              type: 'cube_analytics',
              query: {
                measures: ['TrackedEvents.count'],
                filters: [
                  {
                    member: 'TrackedEvents.event',
                    operator: 'equals',
                    values: ['click'],
                  },
                ],
                limit: 100,
                timezone: 'UTC',
                dimensions: [],
                timeDimensions: [],
              },
            },
            options: {},
            __typename: 'CustomizableDashboardVisualization',
          },
        ],
      },
    },
  },
};

export const mockDateRangeFilterChangePayload = {
  startDate: new Date('2016-01-01'),
  endDate: new Date('2016-02-01'),
  dateRangeOption: 'foo',
};

export const mockMilestoneToken = {
  icon: 'milestone',
  title: TOKEN_TITLE_MILESTONE,
  type: TOKEN_TYPE_MILESTONE,
  token: MilestoneToken,
  unique: true,
  symbol: '%',
};

export const mockLabelToken = {
  icon: 'labels',
  title: TOKEN_TITLE_LABEL,
  type: TOKEN_TYPE_LABEL,
  token: LabelToken,
  unique: false,
  symbol: '~',
  maxSuggestions: FILTERED_SEARCH_MAX_LABELS,
};

export const mockAuthorToken = {
  icon: 'pencil',
  title: TOKEN_TITLE_AUTHOR,
  type: TOKEN_TYPE_AUTHOR,
  token: UserToken,
  dataType: 'user',
  unique: true,
};

export const mockAssigneeToken = {
  icon: 'user',
  title: TOKEN_TITLE_ASSIGNEE,
  type: TOKEN_TYPE_ASSIGNEE,
  token: UserToken,
  dataType: 'user',
  unique: false,
};

export const mockSourceBranchToken = {
  icon: 'branch',
  title: TOKEN_TITLE_SOURCE_BRANCH,
  type: TOKEN_TYPE_SOURCE_BRANCH,
  token: BranchToken,
  unique: true,
  operators: OPERATORS_IS,
};

export const mockTargetBranchToken = {
  icon: 'branch',
  title: TOKEN_TITLE_TARGET_BRANCH,
  type: TOKEN_TYPE_TARGET_BRANCH,
  token: BranchToken,
  unique: true,
  operators: OPERATORS_IS,
};

export const mockFilteredSearchFilters = [
  {
    type: TOKEN_TYPE_AUTHOR,
    value: {
      data: 'root',
      operator: '=',
    },
    id: 'token-14',
  },
  {
    type: TOKEN_TYPE_MILESTONE,
    value: {
      data: 'Any',
      operator: '=',
    },
    id: 'token-16',
  },
  {
    type: TOKEN_TYPE_LABEL,
    value: {
      data: 'Afterpod',
      operator: '=',
    },
    id: 'token-18',
  },
  {
    type: TOKEN_TYPE_ASSIGNEE,
    value: {
      data: 'root',
      operator: '=',
    },
    id: 'token-20',
  },
  {
    type: TOKEN_TYPE_ASSIGNEE,
    value: {
      data: 'vsm-user-1-1737989060',
      operator: '!=',
    },
    id: 'token-24',
  },
  {
    id: 'token-25',
    type: FILTERED_SEARCH_TERM,
    value: {
      data: '',
    },
  },
];

export const mockFilteredSearchChangePayload = {
  [TOKEN_TYPE_ASSIGNEE]: [
    {
      operator: '=',
      value: 'root',
    },
    {
      operator: '!=',
      value: 'vsm-user-1-1737989060',
    },
  ],
  [TOKEN_TYPE_AUTHOR]: [
    {
      operator: '=',
      value: 'root',
    },
  ],
  [TOKEN_TYPE_LABEL]: [
    {
      operator: '=',
      value: 'Afterpod',
    },
  ],
  [TOKEN_TYPE_MILESTONE]: [
    {
      operator: '=',
      value: 'Any',
    },
  ],
};

export const mockFilteredSearchQueryObj = {
  [TOKEN_TYPE_MILESTONE]: ['Any'],
  [TOKEN_TYPE_AUTHOR]: ['root'],
  [TOKEN_TYPE_LABEL]: ['Afterpod'],
  [TOKEN_TYPE_ASSIGNEE]: ['root'],
  [`not[${TOKEN_TYPE_ASSIGNEE}]`]: ['vsm-user-1-1737989060'],
};

export const mockFilteredSearchEmptyQueryObj = {
  [TOKEN_TYPE_MILESTONE]: null,
  [TOKEN_TYPE_AUTHOR]: null,
  [TOKEN_TYPE_LABEL]: null,
  [TOKEN_TYPE_ASSIGNEE]: null,
  [`not[${TOKEN_TYPE_MILESTONE}]`]: null,
  [`not[${TOKEN_TYPE_AUTHOR}]`]: null,
  [`not[${TOKEN_TYPE_LABEL}]`]: null,
  [`not[${TOKEN_TYPE_ASSIGNEE}]`]: null,
};

export const mockLabel1 = {
  id: 'gid://gitlab/GroupLabel/121',
  title: 'UX',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockLabel2 = {
  id: 'gid://gitlab/GroupLabel/122',
  title: 'frontend',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockProjectLabelsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      labels: {
        nodes: [mockLabel1, mockLabel2],
      },
      __typename: 'Project',
    },
  },
};

export const mockGroupLabelsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      labels: {
        nodes: [mockLabel1, mockLabel2],
      },
      __typename: 'Group',
    },
  },
};

export const mockGroupNamespaceMetadata = {
  id: 225,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org',
  namespaceType: 'Group',
  namespaceTypeIcon: 'group',
  visibilityLevelIcon: 'earth',
  visibilityLevelTooltip:
    'Public - The group and any public projects can be viewed without any authentication.',
};

export const mockProjectNamespaceMetadata = {
  id: 7,
  avatarUrl: '/avatar.png',
  fullName: 'GitLab Org / GitLab',
  namespaceType: 'Project',
  namespaceTypeIcon: 'project',
  visibilityLevelIcon: 'shield',
  visibilityLevelTooltip:
    'Internal - The project can be accessed by any logged in user except external users.',
};

export const dataSeries = {
  areaStyle: {
    opacity: 0,
  },
  data: [[null, 23508]],
  itemStyle: {
    color: '#617ae2',
  },
  lineStyle: {
    color: '#617ae2',
  },
  name: 'Lead time for changes',
  showAllSymbol: true,
  showSymbol: true,
  symbolSize: 8,
};

export const medianSeries = {
  areaStyle: {
    opacity: 0,
  },
  showSymbol: false,
  data: [[null, 23508]],
  name: 'Median (last 180d)',
};

export const nullSeries = {
  areaStyle: {
    color: 'none',
  },
  data: [[null, null]],
  itemStyle: {
    color: '#a4a3a8',
  },
  lineStyle: {
    color: '#a4a3a8',
    type: 'dashed',
  },
  name: 'No merge requests were deployed during this period',
  showSymbol: false,
  id: NULL_SERIES_ID,
};

export const mockRepositoryBranchNamesResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/34',
      repository: {
        branchNames: [
          'master',
          "'test'",
          '2-mb-file',
          'Amfunc-Trynt-320',
          'Aquafunc-Panapod-382',
          'NDC-Sosync-649',
          'Onesync-DNF-249',
          'Phant-Techbalt-941',
          'Phest-Phieck-278',
          'Phiestwood-Phyckwood-340',
        ],
        __typename: 'Repository',
      },
    },
  },
};

export const TEST_EMPTY_DASHBOARD_SVG_PATH = 'illustration/empty-state/empty-dashboard-md';

export const createVisualization = () => ({
  version: 1,
  type: 'LineChart',
  slug: 'test_visualization',
  data: {
    type: 'cube_analytics',
    query: {
      measures: ['TrackedEvents.count'],
      timeDimensions: [
        {
          dimension: 'TrackedEvents.utcTime',
          granularity: 'day',
        },
      ],
      limit: 100,
      timezone: 'UTC',
      filters: [],
      dimensions: [],
    },
  },
});

export const dashboard = {
  id: 'analytics_overview',
  slug: 'analytics_overview',
  title: 'Analytics Overview',
  description: 'This is a dashboard',
  userDefined: true,
  panels: [
    {
      title: 'Test A',
      gridAttributes: { width: 3, height: 3 },
      visualization: createVisualization(),
      queryOverrides: null,
      id: getUniquePanelId(),
    },
    {
      title: 'Test B',
      gridAttributes: { width: 2, height: 4, minHeight: 2, minWidth: 2 },
      visualization: createVisualization(),
      queryOverrides: {
        limit: 200,
      },
      id: getUniquePanelId(),
    },
  ],
  status: null,
  errors: null,
};

export const betaDashboard = {
  title: 'Test Dashboard',
  description: 'This dashboard is a work-in-progress',
  status: 'beta',
  panels: [
    {
      title: 'Test A',
      gridAttributes: { width: 3, height: 3 },
      visualization: createVisualization(),
      queryOverrides: {},
      id: getUniquePanelId(),
    },
  ],
};
