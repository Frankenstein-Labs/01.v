import fetch from 'ee/analytics/analytics_dashboards/data_sources/value_stream';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Value Stream Data Source', () => {
  let obj;

  const namespace = 'cool namespace';
  const title = 'fake title';

  const mockNamespaceResponse = {
    data: { project: null, group: { name: namespace, id: '1' } },
  };

  beforeEach(() => {
    jest.spyOn(defaultClient, 'query').mockResolvedValue(mockNamespaceResponse);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('when the namespace resolves to neither a group nor a project', () => {
    beforeEach(() => {
      jest
        .spyOn(defaultClient, 'query')
        .mockResolvedValue({ data: { project: null, group: null } });
    });

    // Happens on the explore dashboard before a group or project is picked.
    // Returning an empty object renders the panel's empty state.
    it('returns an empty object rather than throwing', async () => {
      await expect(fetch({ namespace: '', title, query: {} })).resolves.toStrictEqual({});
    });
  });

  describe('fetch', () => {
    it('returns namespace, title, and all allowed filter fields', async () => {
      const filters = {
        includeMetrics: ['metric_a'],
        excludeMetrics: ['metric_b'],
        labels: ['bug'],
        projectTopics: ['frontend'],
      };

      obj = await fetch({ namespace, title, query: { filters } });

      expect(obj).toStrictEqual({ namespace, title, filters });
    });

    it('drops arbitrary query fields', async () => {
      obj = await fetch({
        namespace,
        title,
        query: { filters: { excludeMetrics: [] }, foo: 'bar', baz: { key: 'value' } },
      });

      expect(obj).toStrictEqual({
        namespace,
        title,
        filters: { excludeMetrics: [] },
      });
    });

    it('drops arbitrary filter sub-fields', async () => {
      obj = await fetch({
        namespace,
        title,
        query: {
          filters: { excludeMetrics: ['metric_a'], foo: 'bar', baz: { key: 'value' } },
        },
      });

      expect(obj).toStrictEqual({
        namespace,
        title,
        filters: { excludeMetrics: ['metric_a'] },
      });
    });
  });
});
