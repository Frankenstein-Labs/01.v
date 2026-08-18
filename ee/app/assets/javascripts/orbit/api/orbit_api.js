// REST API bindings for the Orbit query engine and schema endpoint.
import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

const ORBIT_QUERY_PATH = '/api/:version/orbit/query';
const ORBIT_NAMED_QUERY_PATH = '/api/:version/orbit/query/:name';
const ORBIT_TEMPLATES_PATH = '/api/:version/orbit/query/templates';
const ORBIT_SCHEMA_PATH = '/api/:version/orbit/schema';
const ORBIT_STATUS_PATH = '/api/:version/orbit/status';
const ORBIT_TOOLS_PATH = '/api/:version/orbit/tools';
const ORBIT_GRAPH_STATUS_PATH = '/api/:version/orbit/graph_status';

const GRAPH_STATUS_TIMEOUT_MS = 15000;

/** POST a structured query to the Orbit query engine. */
export const executeOrbitQuery = (query, { responseFormat = 'raw', sourceType } = {}) => {
  const body = { query, response_format: responseFormat };
  if (sourceType) body.source_type = sourceType;
  return axios.post(buildApiUrl(ORBIT_QUERY_PATH), body);
};

/** POST a server-defined named query to the Orbit query engine. */
export const executeOrbitNamedQuery = (
  name,
  { parameters = {}, responseFormat = 'raw', sourceType } = {},
) => {
  const url = buildApiUrl(ORBIT_NAMED_QUERY_PATH).replace(':name', encodeURIComponent(name));
  const body = { parameters, response_format: responseFormat };
  if (sourceType) body.source_type = sourceType;
  return axios.post(url, body);
};

/**
 * GET the named-query catalog: each entry's `raw_query` is the query DSL
 * already rendered for the current user (identity bindings resolved,
 * parameters filled with their declared examples) and executable as-is via
 * `executeOrbitQuery`.
 */
export const fetchOrbitTemplates = () => axios.get(buildApiUrl(ORBIT_TEMPLATES_PATH));

/** GET the Orbit schema introspection (node types, edges, domains). */
export const fetchOrbitSchema = ({ expand, responseFormat = 'raw' } = {}) => {
  const params = { response_format: responseFormat };
  if (expand) params.expand = expand;
  return axios.get(buildApiUrl(ORBIT_SCHEMA_PATH), { params });
};

/** GET Orbit access and cluster health status. */
export const fetchOrbitStatus = () =>
  axios.get(buildApiUrl(ORBIT_STATUS_PATH), { params: { response_format: 'raw' } });

/** GET the list of available Orbit tools. */
export const fetchOrbitTools = () => axios.get(buildApiUrl(ORBIT_TOOLS_PATH));

/** GET graph indexing status (state + entity counts) for a namespace. */
export const fetchGraphStatus = (fullPath, { signal } = {}) =>
  axios.get(buildApiUrl(ORBIT_GRAPH_STATUS_PATH), {
    params: { full_path: fullPath, response_format: 'raw' },
    timeout: GRAPH_STATUS_TIMEOUT_MS,
    signal,
  });
