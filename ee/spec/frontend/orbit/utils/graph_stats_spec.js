import { fetchGraphStatus } from 'ee/orbit/api/orbit_api';
import { readCache, FIVE_MINUTES_MS } from 'ee/orbit/utils/orbit_cache';
import { fetchCombinedGraphStats, fetchGraphStats, GraphStats } from 'ee/orbit/utils/graph_stats';

jest.mock('ee/orbit/api/orbit_api', () => ({
  fetchGraphStatus: jest.fn(),
}));

describe('GraphStats', () => {
  beforeEach(() => {
    localStorage.clear();
    jest.spyOn(Date, 'now').mockReturnValue(1_000_000);
  });

  afterEach(() => {
    Date.now.mockRestore();
  });

  it('normalizes malformed graph status domains', () => {
    const stats = GraphStats.fromGraphStatus({
      projects: { indexed: '2', total_known: 3 },
      domains: [
        {
          name: 'core',
          items: [
            { name: 'Group', count: '4' },
            { name: null, count: 10 },
          ],
        },
        { name: 'plan', items: null },
        { name: null, items: [{ name: 'Issue', count: 1 }] },
      ],
    });

    expect(stats.getDomains()).toEqual([{ name: 'core', items: [{ name: 'Group', count: 4 }] }]);
    expect(stats.getProjects()).toEqual({ indexed: 2, totalKnown: 3 });
    expect(stats.getEntityCounts()).toEqual({ group: 4 });
    expect(stats.getTotalIndexedNodes()).toBe(4);
  });

  it('fetches graph status through the five minute cache', async () => {
    fetchGraphStatus.mockResolvedValue({
      data: { domains: [{ name: 'core', items: [{ name: 'Project', count: 5 }] }] },
    });

    const first = await fetchGraphStats('gitlab-org');
    const second = await fetchGraphStats('gitlab-org');

    expect(first.getEntityCounts()).toEqual({ project: 5 });
    expect(second.getEntityCounts()).toEqual({ project: 5 });
    expect(fetchGraphStatus).toHaveBeenCalledTimes(1);
    expect(readCache('graph-status:gitlab-org')).toEqual({
      domains: [{ name: 'core', items: [{ name: 'Project', count: 5 }] }],
    });

    Date.now.mockReturnValue(1_000_000 + FIVE_MINUTES_MS + 1);
    await fetchGraphStats('gitlab-org');

    expect(fetchGraphStatus).toHaveBeenCalledTimes(2);
  });

  it('combines graph status counts across namespaces', async () => {
    fetchGraphStatus.mockImplementation((fullPath) => {
      if (fullPath === 'frontend') {
        return Promise.resolve({
          data: { domains: [{ name: 'core', items: [{ name: 'Project', count: 3 }] }] },
        });
      }

      return Promise.resolve({
        data: {
          domains: [
            {
              name: 'core',
              items: [
                { name: 'Project', count: 2 },
                { name: 'MergeRequest', count: 4 },
              ],
            },
          ],
        },
      });
    });

    const stats = await fetchCombinedGraphStats(['frontend', 'gitlab-org', 'frontend']);

    expect(fetchGraphStatus).toHaveBeenCalledTimes(2);
    expect(stats.getEntityCounts()).toEqual({ project: 5, mergerequest: 4 });
    expect(stats.getTotalIndexedNodes()).toBe(9);
  });
});
