import { fetchGraphStatus } from '../api/orbit_api';
import { FIVE_MINUTES_MS, withCache } from './orbit_cache';

const GRAPH_STATUS_CACHE_PREFIX = 'graph-status';

const normalizeCount = (value) => {
  const count = Number(value);
  return Number.isFinite(count) && count > 0 ? count : 0;
};

const normalizeName = (value) => (typeof value === 'string' ? value : '');

const normalizeItems = (items) =>
  (Array.isArray(items) ? items : [])
    .map((item = {}) => ({
      name: normalizeName(item.name),
      count: normalizeCount(item.count),
    }))
    .filter(({ name }) => name);

const normalizeDomains = (domains) =>
  (Array.isArray(domains) ? domains : [])
    .map((domain = {}) => ({
      name: normalizeName(domain.name),
      items: normalizeItems(domain.items),
    }))
    .filter(({ name, items }) => name && items.length);

const normalizeProjects = (projects = {}) => {
  const value = projects ?? {};

  return {
    indexed: normalizeCount(value.indexed),
    totalKnown: normalizeCount(value.total_known),
  };
};

const uniqueFullPaths = (fullPaths = []) => [
  ...new Set(
    (Array.isArray(fullPaths) ? fullPaths : []).filter(
      (fullPath) => typeof fullPath === 'string' && fullPath.length > 0,
    ),
  ),
];

const graphStatusCacheKey = (fullPath) => `${GRAPH_STATUS_CACHE_PREFIX}:${fullPath}`;

export class GraphStats {
  constructor(response = {}) {
    const { domains = [], projects = {}, indexing = null } = response ?? {};

    this.domains = normalizeDomains(domains);
    this.projects = normalizeProjects(projects);
    this.indexing = indexing;
  }

  static fromGraphStatus(response = {}) {
    return new GraphStats(response);
  }

  static merge(stats = []) {
    const domainItems = new Map();
    const projects = { indexed: 0, total_known: 0 };

    stats.forEach((graphStats) => {
      graphStats.getDomains().forEach((domain) => {
        const items = domainItems.get(domain.name) ?? new Map();

        domain.items.forEach((item) => {
          const key = item.name.toLowerCase();
          const existing = items.get(key) ?? { name: item.name, count: 0 };
          items.set(key, { ...existing, count: existing.count + item.count });
        });

        domainItems.set(domain.name, items);
      });

      const graphProjects = graphStats.getProjects();
      projects.indexed += graphProjects.indexed;
      projects.total_known += graphProjects.totalKnown;
    });

    return new GraphStats({
      domains: [...domainItems.entries()].map(([name, items]) => ({
        name,
        items: [...items.values()],
      })),
      projects,
    });
  }

  getDomains() {
    return this.domains;
  }

  getProjects() {
    return this.projects;
  }

  getEntityCounts() {
    return this.getDomains()
      .flatMap((domain) => domain.items)
      .reduce((counts, item) => {
        const key = item.name.toLowerCase();
        return { ...counts, [key]: (counts[key] ?? 0) + item.count };
      }, {});
  }

  getTotalIndexedNodes() {
    return Object.values(this.getEntityCounts()).reduce((total, count) => total + count, 0);
  }
}

export async function fetchGraphStats(fullPath) {
  if (typeof fullPath !== 'string' || fullPath.length === 0) {
    throw new TypeError('fullPath must be a non-empty string');
  }

  const data = await withCache(graphStatusCacheKey(fullPath), FIVE_MINUTES_MS, async () => {
    const response = await fetchGraphStatus(fullPath);
    return response.data ?? {};
  });

  return GraphStats.fromGraphStatus(data);
}

export async function fetchCombinedGraphStats(fullPaths) {
  const results = await Promise.allSettled(uniqueFullPaths(fullPaths).map(fetchGraphStats));
  const stats = results
    .filter((result) => result.status === 'fulfilled')
    .map((result) => result.value);

  return GraphStats.merge(stats);
}
