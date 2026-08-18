import { safeLoad } from 'js-yaml';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  EVENT_ITEM_TYPE_CUSTOM_AGENT,
  EVENT_ITEM_TYPE_CUSTOM_FLOW,
  EVENT_ITEM_TYPE_CUSTOM_EXTERNAL_AGENT,
  EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT,
  EVENT_ITEM_TYPE_FOUNDATIONAL_FLOW,
  EVENT_ITEM_TYPE_FOUNDATIONAL_EXTERNAL_AGENT,
  EVENT_FOUNDATIONAL_AGENT_FLOW_NAME,
  EVENT_CUSTOM_AGENT_ITEM_SCHEMA_VERSION,
} from './constants';

const LIST_SEPARATOR = ',';

const REFERENCE_SEPARATOR = '/';

// A foundational flow's `foundationalFlowReference` is a "<name>/<schema_version>"
// string (e.g. "code_review/v1"), split here into its parts.
const foundationalFlowReferenceParts = (item) => {
  const [name, schemaVersion] = String(item.foundationalFlowReference ?? '').split(
    REFERENCE_SEPARATOR,
  );

  return { name: name || undefined, schemaVersion: schemaVersion || undefined };
};

const FOUNDATIONAL_ITEM_TYPES = {
  [AI_CATALOG_TYPE_FLOW]: EVENT_ITEM_TYPE_FOUNDATIONAL_FLOW,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: EVENT_ITEM_TYPE_FOUNDATIONAL_EXTERNAL_AGENT,
  [AI_CATALOG_TYPE_AGENT]: EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT,
};

const CUSTOM_ITEM_TYPES = {
  [AI_CATALOG_TYPE_FLOW]: EVENT_ITEM_TYPE_CUSTOM_FLOW,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: EVENT_ITEM_TYPE_CUSTOM_EXTERNAL_AGENT,
  [AI_CATALOG_TYPE_AGENT]: EVENT_ITEM_TYPE_CUSTOM_AGENT,
};

const findEventItemType = (item) => {
  const typesByItemType = item.foundational ? FOUNDATIONAL_ITEM_TYPES : CUSTOM_ITEM_TYPES;

  return typesByItemType[item.itemType];
};

// Foundational flows and agents are identified by their references rather than
// an ID, so custom_item_id is omitted for them.
const findCustomItemId = (item) => {
  const itemType = findEventItemType(item);

  if ([EVENT_ITEM_TYPE_FOUNDATIONAL_FLOW, EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT].includes(itemType)) {
    return undefined;
  }

  return getIdFromGraphQLId(item.id);
};

const joinList = (list) => {
  if (!Array.isArray(list)) {
    return undefined;
  }

  const filtered = list.filter((value) => value !== undefined && value !== null && value !== '');

  return filtered.length > 0 ? filtered.join(LIST_SEPARATOR) : undefined;
};

const agentToolNames = (version) => joinList(version.tools?.nodes?.map((tool) => tool.name));

const agentMcpServerIds = (version) =>
  joinList(version.mcpServers?.nodes?.map((server) => getIdFromGraphQLId(server.id)));

const parseFlowDefinition = (definition) => {
  if (definition && typeof definition === 'object') {
    return definition;
  }

  if (typeof definition !== 'string') {
    return {};
  }

  const parsed = safeLoad(definition);

  return parsed && typeof parsed === 'object' ? parsed : {};
};

const flowToolNames = ({ components = [] }) => {
  const names = components.flatMap((component) => {
    if (component.toolset) {
      return component.toolset.map((entry) =>
        entry !== null && typeof entry === 'object' ? Object.keys(entry)[0] : entry,
      );
    }

    if (component.tool_name) {
      return [component.tool_name];
    }

    return [];
  });

  return joinList(names);
};

// Component types defined in a flow definition, preserving multiplicity.
const flowComponentTypes = ({ components = [] }) =>
  joinList(components.map((component) => component.type));

const customFlowSchemaVersion = ({ version }) => version || undefined;

/**
 * Builds the granular AI Catalog tracking properties for an item.
 *
 * The identity properties (`item_type`, `custom_item_id`, `item_version`,
 * `flow_name`, `component_name`, and for foundational flows
 * `item_schema_version`) are always derived from the base item. The richer
 * fields (`tools`, `mcp_tools`, `mcp_servers`, `components`, and the
 * custom-flow `item_schema_version`) are only populated when a fully-loaded
 * `version` is provided (e.g. on the item show page), to avoid pulling version
 * definitions on list/index pages.
 *
 * @param {Object} item - An AiCatalogItem GraphQL object.
 * @param {Object} [options]
 * @param {Object} [options.version] - A fully-loaded version object (agent or
 *   flow). When omitted, only the identity properties are returned.
 * @returns {Object} A flat properties hash with undefined values removed.
 */
export const buildAiCatalogEventProperties = (item, { version } = {}) => {
  try {
    const itemType = findEventItemType(item);

    if (!itemType) {
      throw new Error(`Unable to derive AI Catalog item_type from itemType: ${item?.itemType}`);
    }

    const properties = {
      item_type: itemType,
      custom_item_id: findCustomItemId(item),
      item_version: item.latestVersion?.versionName,
    };

    if (itemType === EVENT_ITEM_TYPE_FOUNDATIONAL_FLOW) {
      const { name, schemaVersion } = foundationalFlowReferenceParts(item);

      properties.flow_name = name;
      properties.item_schema_version = schemaVersion;
    } else if (itemType === EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT) {
      properties.flow_name = EVENT_FOUNDATIONAL_AGENT_FLOW_NAME;
      properties.component_name = item.foundationalAgentReference || undefined;
    }

    if (version) {
      properties.item_version = version.versionName ?? properties.item_version;

      if ([EVENT_ITEM_TYPE_CUSTOM_AGENT, EVENT_ITEM_TYPE_FOUNDATIONAL_AGENT].includes(itemType)) {
        properties.tools = agentToolNames(version);
        properties.mcp_tools = joinList(version.mcpTools);
        properties.mcp_servers = agentMcpServerIds(version);
        properties.item_schema_version =
          version.schemaVersion ?? EVENT_CUSTOM_AGENT_ITEM_SCHEMA_VERSION;
        // Foundational flow definitions live in Duo Workflow Service and are not
        // visible to Rails, so definition data is only recorded for custom flows.
      } else if (itemType === EVENT_ITEM_TYPE_CUSTOM_FLOW) {
        const definition = parseFlowDefinition(version.definition);

        properties.tools = flowToolNames(definition);
        properties.components = flowComponentTypes(definition);
        properties.item_schema_version = customFlowSchemaVersion(definition);
      }
    }

    return Object.fromEntries(
      Object.entries(properties).filter(([, value]) => value !== undefined),
    );
  } catch (error) {
    captureException(error, {
      extra: { item_type: item?.itemType, item_id: item?.id, version_name: version?.versionName },
    });

    if (process.env.NODE_ENV !== 'production') {
      throw error;
    }

    return {};
  }
};
