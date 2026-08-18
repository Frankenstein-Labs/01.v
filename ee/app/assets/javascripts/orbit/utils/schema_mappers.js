// Filters, groups, and maps schema metadata for the schema browser page.

/**
 * Enriches schema domains with node counts and sorts alphabetically.
 * @param {import('../api/schema_types').SchemaDomain[]} domains
 * @returns {Array<SchemaDomain & {count: number}>}
 */
export function mapSchemaDomains(domains) {
  return (domains || [])
    .map((d) => ({ ...d, count: (d.node_names || []).length }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Maps node names to their domain for cross-referencing in the schema browser.
 * @param {import('../api/schema_types').SchemaNode[]} schemaNodes
 * @returns {Object<string, string>}
 */
export function buildNodeDomainMap(schemaNodes) {
  return Object.fromEntries((schemaNodes || []).map((n) => [n.name, n.domain]));
}

/**
 * Builds a domain-to-color map using the first node color found per domain.
 * @param {import('../api/schema_types').SchemaNode[]} schemaNodes
 * @param {Object} nodeStyleMap
 * @param {string} [fallbackColor]
 * @returns {Object<string, string>}
 */
export function buildDomainColorMap(schemaNodes, nodeStyleMap, fallbackColor = null) {
  return (schemaNodes || []).reduce((map, n) => {
    if (!map[n.domain]) {
      const color = nodeStyleMap[n.name.toLowerCase()]?.color;
      map[n.domain] = color || fallbackColor || undefined; // eslint-disable-line no-param-reassign -- reduce accumulator
    }
    return map;
  }, {});
}

/**
 * Resolves display color for a node by name, checking style map then domain color.
 * @param {string} nodeName
 * @param {Object} colorMaps
 * @param {Object} colorMaps.nodeStyleMap
 * @param {Object} [colorMaps.domainColorMap]
 * @param {Object} [colorMaps.nodeDomainMap]
 * @returns {string|null}
 */
export function resolveNodeColor(
  nodeName,
  { nodeStyleMap, domainColorMap = {}, nodeDomainMap = {} },
) {
  if (!nodeName) return null;

  const key = nodeName.toLowerCase();
  const domain = nodeDomainMap[nodeName];
  return nodeStyleMap[key]?.color ?? domainColorMap[domain] ?? null;
}

/**
 * Filters schema nodes by domain and/or free-text query on name, description, and properties.
 * @param {import('../api/schema_types').SchemaNode[]} nodes
 * @param {Object} options
 * @param {string} [options.domain]
 * @param {string} [options.query]
 * @returns {import('../api/schema_types').SchemaNode[]}
 */
export function filterSchemaNodes(nodes, { domain, query } = {}) {
  let filtered = nodes || [];
  if (domain) {
    filtered = filtered.filter((n) => n.domain === domain);
  }
  if (query) {
    const q = query.toLowerCase();
    filtered = filtered.filter(
      (n) =>
        n.name.toLowerCase().includes(q) ||
        (n.description || '').toLowerCase().includes(q) ||
        (n.properties || []).some((p) => p.name.toLowerCase().includes(q)),
    );
  }
  return filtered;
}

/**
 * Filters schema edges by text query and/or domain (via node variant membership).
 * @param {import('../api/schema_types').SchemaEdge[]} edges
 * @param {import('../api/schema_types').SchemaNode[]} nodes
 * @param {Object} options
 * @param {string} [options.domain]
 * @param {string} [options.query]
 * @returns {import('../api/schema_types').SchemaEdge[]}
 */
export function filterSchemaEdges(edges, nodes, { domain, query } = {}) {
  let filtered = edges || [];
  if (query) {
    const q = query.toLowerCase();
    filtered = filtered.filter(
      (e) => e.name.toLowerCase().includes(q) || (e.description || '').toLowerCase().includes(q),
    );
  }
  if (domain) {
    const domainNodes = new Set(
      (nodes || []).filter((n) => n.domain === domain).map((n) => n.name),
    );
    filtered = filtered.filter((e) =>
      (e.variants || []).some(
        (v) => domainNodes.has(v.source_type) || domainNodes.has(v.target_type),
      ),
    );
  }
  return filtered;
}
