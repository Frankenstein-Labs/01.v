/**
 * @typedef {Object} SchemaNodeProperty
 * @property {string} name
 * @property {string} data_type
 * @property {boolean} [nullable]
 */

/**
 * @typedef {Object} SchemaNodeStyle
 * @property {string} [color]
 * @property {number} [size]
 */

/**
 * @typedef {Object} SchemaNode
 * @property {string} name
 * @property {string} domain
 * @property {string} [description]
 * @property {string} [primary_key]
 * @property {string} [label_field]
 * @property {SchemaNodeProperty[]} [properties]
 * @property {SchemaNodeStyle} [style]
 */

/**
 * @typedef {Object} SchemaEdgeVariant
 * @property {string} source_type
 * @property {string} target_type
 */

/**
 * @typedef {Object} SchemaEdge
 * @property {string} name
 * @property {string} [description]
 * @property {SchemaEdgeVariant[]} [variants]
 */

/**
 * @typedef {Object} SchemaDomain
 * @property {string} name
 * @property {string} [description]
 * @property {string[]} [node_names]
 */

const SCHEMA_NODE_REQUIRED_KEYS = ['name', 'domain'];
const SCHEMA_EDGE_REQUIRED_KEYS = ['name'];

/** Validates that a schema node object has all required keys (name, domain). */
export const schemaNodeValidator = (node) =>
  Boolean(node) && SCHEMA_NODE_REQUIRED_KEYS.every((key) => Object.hasOwn(node, key));

/** Validates that a schema edge object has all required keys (name). */
export const schemaEdgeValidator = (edge) =>
  Boolean(edge) && SCHEMA_EDGE_REQUIRED_KEYS.every((key) => Object.hasOwn(edge, key));
