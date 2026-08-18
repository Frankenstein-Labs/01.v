import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_agent_platform_flows_usage_by_user';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { DATE_RANGE_OPTION_LAST_7_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('AI Agent platform flow metrics data source', () => {
  const namespace = 'namespace';
  const user = {
    id: 1,
    avatarUrl: 'test.com',
    name: 'Test',
    username: 'test',
    webUrl: 'web.test.com',
    webPath: '/test',
  };
  const mockNodes = [
    {
      flowType: 'a',
      sessionsCount: 100,
      user,
    },
    {
      flowType: 'b',
      sessionsCount: 300,
      user,
    },
  ];

  const mockResolvedQuery = ({ nodes = mockNodes, pageInfo = {} } = {}) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          aiMetrics: { agentPlatform: { userFlowCounts: { nodes, pageInfo } } },
        },
      },
    });

  it('returns the flow metrics as nodes on success', async () => {
    mockResolvedQuery();

    const result = await fetch({ namespace });
    expect(result).toMatchSnapshot();
  });

  it('returns an empty object if there are no results', async () => {
    mockResolvedQuery({ nodes: [] });

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

  it('fetches the next page', async () => {
    const pageInfo = { hasNextPage: true, endCursor: 'page3' };
    mockResolvedQuery({ nodes: mockNodes, pageInfo });

    const response = await fetch({
      namespace,
      query: {
        pagination: {
          first: 50,
          endCursor: 'page2',
        },
      },
    });

    expect(response.pageInfo).toMatchObject(pageInfo);
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: '2020-06-06',
          endDate: '2020-07-06',
          first: 50,
          after: 'page2',
        }),
      }),
    );
  });

  it('fetches the previous page', async () => {
    const pageInfo = { hasPreviousPage: true, startCursor: 'page1' };
    mockResolvedQuery({ nodes: mockNodes, pageInfo });

    const response = await fetch({
      namespace,
      query: {
        pagination: {
          last: 50,
          startCursor: 'page2',
        },
      },
    });

    expect(response.pageInfo).toMatchObject(pageInfo);
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining({
          fullPath: namespace,
          startDate: '2020-06-06',
          endDate: '2020-07-06',
          last: 50,
          before: 'page2',
        }),
      }),
    );
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
