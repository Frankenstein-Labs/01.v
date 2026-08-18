// Maps schema node definitions to display styles (colors, sizes, labels).
// Sits between schema fetch and graph rendering.
import { ENTITY_TYPE_COLORS } from '../constants';

/**
 * Builds a lookup table from schema node definitions to visual style properties.
 * Called after schema fetch; the returned map is used during graph rendering.
 * @param {import('../api/schema_types').SchemaNode[]} schemaNodes
 * @returns {Object<string, {name: string, domain: string, labelField: string, primaryKey: string, color: string, size: number}>}
 */
export function buildNodeStyleMap(schemaNodes) {
  return Object.fromEntries(
    (schemaNodes || []).map((node) => {
      const key = node.name.toLowerCase();
      return [
        key,
        {
          name: node.name,
          domain: node.domain,
          labelField: node.label_field,
          primaryKey: node.primary_key,
          color: node.style?.color || ENTITY_TYPE_COLORS[key] || ENTITY_TYPE_COLORS.default,
          size: node.style?.size ?? 30,
        },
      ];
    }),
  );
}

/** Extracts schema-defined colors keyed by lowercase entity name. */
export function entityColorsFromSchema(schemaNodes) {
  return Object.fromEntries(
    (schemaNodes || [])
      .filter((node) => node.style?.color)
      .map((node) => [node.name.toLowerCase(), node.style.color]),
  );
}

/** Extracts display names keyed by lowercase entity name. */
export function entityNamesFromSchema(schemaNodes) {
  return Object.fromEntries(
    (schemaNodes || []).map((node) => [node.name.toLowerCase(), node.name]),
  );
}
