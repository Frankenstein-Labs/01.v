import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_agent_platform_flow_metrics';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { DATE_RANGE_OPTION_LAST_7_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

const mockFlowMetrics = [
  {
    flowType: 'AGENT_FLOW',
    medianExecutionTime: 1250,
    sessionsCount: 145,
    usersCount: 32,
    completionRate: 92.5,
  },
  {
    flowType: 'TOOL_FLOW',
    medianExecutionTime: 850,
    sessionsCount: 203,
    usersCount: 48,
    completionRate: 88.3,
  },
  {
    flowType: 'CUSTOM_FLOW',
    medianExecutionTime: 0,
    sessionsCount: 87,
    usersCount: 19,
    completionRate: 95.1,
  },
  {
    flowType: 'BONUS_FLOW',
    medianExecutionTime: null,
    sessionsCount: 87,
    usersCount: 19,
    completionRate: 95.1,
  },
];

describe('AI Agent platform flow metrics data source', () => {
  const namespace = 'namespace';

  const mockResolvedQuery = (flowMetrics = mockFlowMetrics) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({
      data: {
        group: { id: 'gid://gitlab/Group/1', aiMetrics: { agentPlatform: { flowMetrics } } },
      },
    });

  it('returns the flow metrics as nodes on success', async () => {
    mockResolvedQuery();

    const result = await fetch({ namespace });
    expect(result).toMatchSnapshot();
  });

  it('returns an empty object if there are no results', async () => {
    mockResolvedQuery([]);

    const result = await fetch({ namespace });
    expect(result).toEqual({});
  });

  it('uses 30 days as the default date range', async () => {
    mockResolvedQuery();
    await fetch({ namespace });

    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: '2020-06-06',
          endDate: '2020-07-06',
        }),
      }),
    );
  });

  it('uses a custom date range when defined', async () => {
    mockResolvedQuery();
    await fetch({
      namespace,
      query: { dateRange: DATE_RANGE_OPTION_LAST_7_DAYS },
    });

    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: '2020-06-29',
          endDate: '2020-07-06',
        }),
      }),
    );
  });

  it('correctly applies default sorting query parameters when available', async () => {
    mockResolvedQuery();
    const result = await fetch({
      namespace,
      query: { sortBy: 'sessionsCount', sortDesc: false },
    });

    expect(result.nodes).toMatchSnapshot();
  });

  it('ignores sorting when the fields are excluded', async () => {
    mockResolvedQuery();
    const result = await fetch({ namespace });

    expect(result.nodes).toMatchSnapshot();
  });

  it.each([
    ['sessionsCount', true],
    ['sessionsCount', false],
    ['medianExecutionTime', true],
    ['medianExecutionTime', false],
    ['usersCount', true],
    ['usersCount', false],
  ])('applies correct sorting for (sortBy: %s, sortDesc: %s)', async (sortBy, sortDesc) => {
    mockResolvedQuery();
    const result = await fetch({
      namespace,
      query: { sortBy, sortDesc },
    });

    expect(result.nodes).toMatchSnapshot();
  });

  // The namespace resolves to nothing before a group or project is picked on
  // the explore dashboard, and aiMetrics is absent when it is unavailable.
  // Either way the panel should fall back to its empty state.
  it.each([
    ['the namespace resolves to neither a group nor a project', { project: null, group: null }],
    [
      'the namespace exposes no aiMetrics',
      { group: { id: 'gid://gitlab/Group/1', aiMetrics: null } },
    ],
  ])('returns an empty object when %s', async (_, data) => {
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data });

    await expect(fetch({ namespace, query: {} })).resolves.toStrictEqual({});
  });
});
