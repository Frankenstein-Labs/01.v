import MockAdapter from 'axios-mock-adapter';
import {
  executeOrbitNamedQuery,
  executeOrbitQuery,
  fetchGraphStatus,
  fetchOrbitSchema,
  fetchOrbitStatus,
  fetchOrbitTemplates,
  fetchOrbitTools,
} from 'ee/orbit/api/orbit_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';

const GRAPH_STATUS_TIMEOUT_MS = 15000;

describe('orbit_api', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    gon.api_version = 'v4';
  });

  afterEach(() => {
    mock.restore();
  });

  describe('executeOrbitQuery', () => {
    const queryUrl = '/api/v4/orbit/query';

    it('sends a POST with the query and default options', async () => {
      const queryPayload = { query_type: 'traversal', node: { id: 'u', entity: 'User' } };
      const responseData = { nodes: [], edges: [] };

      mock.onPost(queryUrl).reply(HTTP_STATUS_OK, responseData);

      const { data } = await executeOrbitQuery(queryPayload);

      expect(data).toEqual(responseData);
      expect(JSON.parse(mock.history.post[0].data)).toEqual({
        query: queryPayload,
        response_format: 'raw',
      });
    });

    it('forwards custom responseFormat', async () => {
      const query = { query_type: 'traversal', node: { id: 'u', entity: 'User' } };

      mock.onPost(queryUrl).reply(HTTP_STATUS_OK, {});

      await executeOrbitQuery(query, { responseFormat: 'graph' });

      expect(JSON.parse(mock.history.post[0].data)).toEqual({
        query,
        response_format: 'graph',
      });
    });

    it('rejects on server error', async () => {
      mock.onPost(queryUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(executeOrbitQuery({})).rejects.toThrow();
    });
  });

  describe('executeOrbitNamedQuery', () => {
    const namedQueryUrl = '/api/v4/orbit/query/my_neighbors';

    it('sends a POST to the named query path with default options', async () => {
      const responseData = { result: { nodes: [], edges: [] } };

      mock.onPost(namedQueryUrl).reply(HTTP_STATUS_OK, responseData);

      const { data } = await executeOrbitNamedQuery('my_neighbors');

      expect(data).toEqual(responseData);
      expect(mock.history.post[0].url).toBe(namedQueryUrl);
      expect(JSON.parse(mock.history.post[0].data)).toEqual({
        parameters: {},
        response_format: 'raw',
      });
    });

    it('forwards parameters, responseFormat and sourceType', async () => {
      mock.onPost('/api/v4/orbit/query/expand_neighbors').reply(HTTP_STATUS_OK, {});

      await executeOrbitNamedQuery('expand_neighbors', {
        parameters: { entity: 'Group', node_ids: [1], limit: 50 },
        responseFormat: 'llm',
        sourceType: 'code_intelligence',
      });

      expect(JSON.parse(mock.history.post[0].data)).toEqual({
        parameters: { entity: 'Group', node_ids: [1], limit: 50 },
        response_format: 'llm',
        source_type: 'code_intelligence',
      });
    });

    it('escapes the query name in the URL', async () => {
      mock.onAny().reply(HTTP_STATUS_OK, {});

      await executeOrbitNamedQuery('a/b?c');

      expect(mock.history.post[0].url).toBe('/api/v4/orbit/query/a%2Fb%3Fc');
    });

    it('rejects on server error', async () => {
      mock.onPost(namedQueryUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(executeOrbitNamedQuery('my_neighbors')).rejects.toThrow();
    });
  });

  describe('fetchOrbitTemplates', () => {
    const templatesUrl = '/api/v4/orbit/query/templates';

    it('sends a GET request', async () => {
      const templatesData = [
        {
          name: 'my_neighbors',
          description: 'Immediate graph neighborhood of the current user.',
          raw_query: { query_type: 'neighbors', limit: 100 },
        },
      ];

      mock.onGet(templatesUrl).reply(HTTP_STATUS_OK, templatesData);

      const { data } = await fetchOrbitTemplates();

      expect(data).toEqual(templatesData);
    });

    it('rejects on server error', async () => {
      mock.onGet(templatesUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(fetchOrbitTemplates()).rejects.toThrow();
    });
  });

  describe('fetchOrbitSchema', () => {
    const schemaUrl = '/api/v4/orbit/schema';

    it('sends a GET with default params', async () => {
      const schemaData = { nodes: [], edges: [] };

      mock.onGet(schemaUrl).reply(HTTP_STATUS_OK, schemaData);

      const { data } = await fetchOrbitSchema();

      expect(data).toEqual(schemaData);
      expect(mock.history.get[0].params).toEqual({ response_format: 'raw' });
    });

    it('includes expand param when provided', async () => {
      mock.onGet(schemaUrl).reply(HTTP_STATUS_OK, {});

      await fetchOrbitSchema({ expand: 'properties' });

      expect(mock.history.get[0].params).toEqual({
        response_format: 'raw',
        expand: 'properties',
      });
    });

    it('forwards custom responseFormat', async () => {
      mock.onGet(schemaUrl).reply(HTTP_STATUS_OK, {});

      await fetchOrbitSchema({ responseFormat: 'graph' });

      expect(mock.history.get[0].params).toEqual({ response_format: 'graph' });
    });

    it('rejects on server error', async () => {
      mock.onGet(schemaUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(fetchOrbitSchema()).rejects.toThrow();
    });
  });

  describe('fetchOrbitStatus', () => {
    const statusUrl = '/api/v4/orbit/status';

    it('sends a GET with raw response_format', async () => {
      const statusData = { status: 'ok' };

      mock.onGet(statusUrl).reply(HTTP_STATUS_OK, statusData);

      const { data } = await fetchOrbitStatus();

      expect(data).toEqual(statusData);
      expect(mock.history.get[0].params).toEqual({ response_format: 'raw' });
    });

    it('rejects on server error', async () => {
      mock.onGet(statusUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(fetchOrbitStatus()).rejects.toThrow();
    });
  });

  describe('fetchOrbitTools', () => {
    const toolsUrl = '/api/v4/orbit/tools';

    it('sends a GET request', async () => {
      const toolsData = [{ name: 'tool1' }];

      mock.onGet(toolsUrl).reply(HTTP_STATUS_OK, toolsData);

      const { data } = await fetchOrbitTools();

      expect(data).toEqual(toolsData);
    });

    it('rejects on server error', async () => {
      mock.onGet(toolsUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(fetchOrbitTools()).rejects.toThrow();
    });
  });

  describe('fetchGraphStatus', () => {
    const graphStatusUrl = '/api/v4/orbit/graph_status';

    it('sends a GET request with the selected namespace full path', async () => {
      const graphStatusData = {
        projects: { indexed: 2, total_known: 3 },
        domains: [],
        indexing: { state: 'indexed' },
      };

      mock.onGet(graphStatusUrl).reply(HTTP_STATUS_OK, graphStatusData);

      const { data } = await fetchGraphStatus('gitlab-org/gitlab');

      expect(data).toEqual(graphStatusData);
      expect(mock.history.get[0].params).toEqual({
        full_path: 'gitlab-org/gitlab',
        response_format: 'raw',
      });
      expect(mock.history.get[0].timeout).toBe(GRAPH_STATUS_TIMEOUT_MS);
    });

    it('forwards the abort signal to axios', async () => {
      const controller = new AbortController();
      mock.onGet(graphStatusUrl).reply(HTTP_STATUS_OK, {});

      await fetchGraphStatus('gitlab-org/gitlab', { signal: controller.signal });

      expect(mock.history.get[0].signal).toBe(controller.signal);
    });

    it('rejects on server error', async () => {
      mock.onGet(graphStatusUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(fetchGraphStatus('gitlab-org')).rejects.toThrow();
    });
  });
});
