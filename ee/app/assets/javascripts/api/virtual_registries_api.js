/* eslint-disable @gitlab/no-hardcoded-urls -- REST API routes using Api.buildUrl is acceptable */
import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

const MAVEN_REGISTRY_CACHE_PATH =
  '/api/:version/virtual_registries/packages/maven/registries/:id/cache';
const MAVEN_UPSTREAM_PATH = '/api/:version/virtual_registries/packages/maven/upstreams/:id';
const MAVEN_UPSTREAM_CACHE_PATH = `${MAVEN_UPSTREAM_PATH}/cache`;
const MAVEN_UPSTREAM_CACHE_ENTRY_PATH =
  '/api/:version/virtual_registries/packages/maven/cache_entries/:id';
const MAVEN_UPSTREAM_TEST_PATH = `${MAVEN_UPSTREAM_PATH}/test`;
const MAVEN_REGISTRY_UPSTREAMS_PATH =
  '/api/:version/virtual_registries/packages/maven/registry_upstreams';
const MAVEN_REGISTRY_UPSTREAM_PATH = `${MAVEN_REGISTRY_UPSTREAMS_PATH}/:id`;
const MAVEN_UPSTREAMS_PATH =
  '/api/:version/groups/:id/-/virtual_registries/packages/maven/upstreams';
const MAVEN_UPSTREAMS_TEST_PATH = `${MAVEN_UPSTREAMS_PATH}/test`;

const buildMavenUpstreamApiUrl = (id) => buildApiUrl(MAVEN_UPSTREAM_PATH).replace(':id', id);

export function updateMavenUpstream({ id, data }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.patch(url, {
    ...data,
  });
}

export function updateMavenRegistryUpstreamPosition({ id, position }) {
  const url = buildApiUrl(MAVEN_REGISTRY_UPSTREAM_PATH).replace(':id', id);

  return axios.patch(url, {
    position,
  });
}

export function associateMavenUpstreamWithVirtualRegistry({ registryId, upstreamId }) {
  const url = buildApiUrl(MAVEN_REGISTRY_UPSTREAMS_PATH);

  return axios.post(url, {
    registry_id: registryId,
    upstream_id: upstreamId,
  });
}

export function removeMavenUpstreamRegistryAssociation({ id }) {
  const url = buildApiUrl(MAVEN_REGISTRY_UPSTREAM_PATH).replace(':id', id);

  return axios.delete(url);
}

export function deleteMavenUpstream({ id }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.delete(url);
}

export function deleteMavenRegistryCache({ id }) {
  const url = buildApiUrl(MAVEN_REGISTRY_CACHE_PATH).replace(':id', id);

  return axios.delete(url);
}

export function deleteMavenUpstreamCache({ id }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_PATH).replace(':id', id);

  return axios.delete(url);
}

export function deleteMavenUpstreamCacheEntry({ id }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_ENTRY_PATH).replace(':id', id);

  return axios.delete(url);
}

export function testMavenUpstream({ id, url, username, password }) {
  const apiUrl = buildApiUrl(MAVEN_UPSTREAMS_TEST_PATH).replace(':id', id);

  return axios.post(apiUrl, {
    url,
    username,
    password,
  });
}

export function testExistingMavenUpstreamWithOverrides({ id, url, username, password }) {
  const apiUrl = buildApiUrl(MAVEN_UPSTREAM_TEST_PATH).replace(':id', id);

  if (url) {
    return axios.post(apiUrl, { url, username, password });
  }
  return axios.post(apiUrl);
}
