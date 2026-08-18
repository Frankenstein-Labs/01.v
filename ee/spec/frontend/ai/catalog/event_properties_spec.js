import { buildAiCatalogEventProperties } from 'ee/ai/catalog/event_properties';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('buildAiCatalogEventProperties', () => {
  const baseItem = ({
    itemType = 'AGENT',
    foundational = false,
    versionName = '1.0.0',
    foundationalFlowReference = null,
    foundationalAgentReference = null,
  } = {}) => ({
    id: 'gid://gitlab/Ai::Catalog::Item/7',
    itemType,
    foundational,
    foundationalFlowReference,
    foundationalAgentReference,
    latestVersion: { versionName },
  });

  describe('identity properties (no version)', () => {
    it('returns custom_agent for a non-foundational agent', () => {
      expect(buildAiCatalogEventProperties(baseItem({ itemType: 'AGENT' }))).toEqual({
        item_type: 'custom_agent',
        custom_item_id: 7,
        item_version: '1.0.0',
      });
    });

    it('returns custom_flow for a non-foundational flow', () => {
      expect(buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }))).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '1.0.0',
      });
    });

    it('returns custom_external_agent for a non-foundational third party flow', () => {
      expect(buildAiCatalogEventProperties(baseItem({ itemType: 'THIRD_PARTY_FLOW' }))).toEqual({
        item_type: 'custom_external_agent',
        custom_item_id: 7,
        item_version: '1.0.0',
      });
    });

    it('returns foundational_agent with flow_name "chat", component_name and omits custom_item_id for a foundational agent', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({
            itemType: 'AGENT',
            foundational: true,
            foundationalAgentReference: 'orbit_agent',
          }),
        ),
      ).toEqual({
        item_type: 'foundational_agent',
        item_version: '1.0.0',
        flow_name: 'chat',
        component_name: 'orbit_agent',
      });
    });

    it('omits component_name for a foundational agent without a reference', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'AGENT', foundational: true })),
      ).toEqual({
        item_type: 'foundational_agent',
        item_version: '1.0.0',
        flow_name: 'chat',
      });
    });

    it('returns foundational_external_agent and includes custom_item_id for a foundational third party flow', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({ itemType: 'THIRD_PARTY_FLOW', foundational: true }),
        ),
      ).toEqual({
        item_type: 'foundational_external_agent',
        custom_item_id: 7,
        item_version: '1.0.0',
      });
    });

    it('derives flow_name and item_schema_version from the reference for a foundational flow', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({
            itemType: 'FLOW',
            foundational: true,
            foundationalFlowReference: 'code_review/v1',
          }),
        ),
      ).toEqual({
        item_type: 'foundational_flow',
        item_version: '1.0.0',
        flow_name: 'code_review',
        item_schema_version: 'v1',
      });
    });

    it('omits item_schema_version when the foundational flow reference has no schema part', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({
            itemType: 'FLOW',
            foundational: true,
            foundationalFlowReference: 'code_review',
          }),
        ),
      ).toEqual({
        item_type: 'foundational_flow',
        item_version: '1.0.0',
        flow_name: 'code_review',
      });
    });

    it('omits flow_name and item_schema_version when a foundational flow has no reference', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW', foundational: true })),
      ).toEqual({
        item_type: 'foundational_flow',
        item_version: '1.0.0',
      });
    });

    it('does not emit flow_name for non-foundational-flow items even if a reference is present', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({
            itemType: 'THIRD_PARTY_FLOW',
            foundational: true,
            foundationalFlowReference: 'code_review/v1',
          }),
        ),
      ).toEqual({
        item_type: 'foundational_external_agent',
        custom_item_id: 7,
        item_version: '1.0.0',
      });
    });

    it('omits item_version when latestVersion is absent', () => {
      const item = baseItem();
      delete item.latestVersion;

      expect(buildAiCatalogEventProperties(item)).toEqual({
        item_type: 'custom_agent',
        custom_item_id: 7,
      });
    });

    it('throws for an unknown item type so the bug is surfaced outside production', () => {
      expect(() => buildAiCatalogEventProperties(baseItem({ itemType: 'SOMETHING_ELSE' }))).toThrow(
        'Unable to derive AI Catalog item_type from itemType: SOMETHING_ELSE',
      );
    });
  });

  describe('agent version properties', () => {
    const agentVersion = {
      versionName: '2.0.0',
      tools: {
        nodes: [{ name: 'read_file' }, { name: 'grep' }],
      },
      mcpTools: ['search', 'create_issue'],
      mcpServers: {
        nodes: [
          { id: 'gid://gitlab/Ai::Catalog::McpServer/1' },
          { id: 'gid://gitlab/Ai::Catalog::McpServer/2' },
        ],
      },
    };

    it('includes tools, mcp_tools, mcp_servers and item_schema_version', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'AGENT' }), { version: agentVersion }),
      ).toEqual({
        item_type: 'custom_agent',
        custom_item_id: 7,
        item_version: '2.0.0',
        item_schema_version: 'v1',
        tools: 'read_file,grep',
        mcp_tools: 'search,create_issue',
        mcp_servers: '1,2',
      });
    });

    it('omits empty agent list fields but still emits item_schema_version', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'AGENT' }), {
          version: {
            versionName: '2.0.0',
            tools: { nodes: [] },
            mcpTools: [],
            mcpServers: { nodes: [] },
          },
        }),
      ).toEqual({
        item_type: 'custom_agent',
        custom_item_id: 7,
        item_version: '2.0.0',
        item_schema_version: 'v1',
      });
    });

    it('emits item_schema_version "v1", flow_name and component_name for a foundational agent with a version', () => {
      expect(
        buildAiCatalogEventProperties(
          baseItem({
            itemType: 'AGENT',
            foundational: true,
            foundationalAgentReference: 'orbit_agent',
          }),
          {
            version: { versionName: '2.0.0', tools: { nodes: [] }, mcpTools: [] },
          },
        ),
      ).toEqual({
        item_type: 'foundational_agent',
        item_version: '2.0.0',
        flow_name: 'chat',
        component_name: 'orbit_agent',
        item_schema_version: 'v1',
      });
    });
  });

  describe('flow version properties', () => {
    const flowDefinitionYaml = `
version: v1
components:
  - name: planner
    type: AgentComponent
    toolset:
      - read_file
      - create_merge_request_note:
          internal: true
  - name: tool_runner
    type: DeterministicStepComponent
    tool_name: edit_file
  - name: executor
    type: AgentComponent
    toolset:
      - read_file
      - grep
`;

    const flowVersion = { versionName: '3.0.0', definition: flowDefinitionYaml };

    it('parses the YAML definition and includes tools, components and item_schema_version', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), { version: flowVersion }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
        item_schema_version: 'v1',
        tools: 'read_file,create_merge_request_note,edit_file,read_file,grep',
        components: 'AgentComponent,DeterministicStepComponent,AgentComponent',
      });
    });

    it('also accepts an already-parsed definition object', () => {
      const definition = {
        version: 'v2',
        components: [{ type: 'AgentComponent', tool_name: 'read_file' }],
      };

      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: { versionName: '3.0.0', definition },
        }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
        item_schema_version: 'v2',
        tools: 'read_file',
        components: 'AgentComponent',
      });
    });

    it('emits item_schema_version but omits list fields when the definition has no components', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: { versionName: '3.0.0', definition: 'version: v1' },
        }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
        item_schema_version: 'v1',
      });
    });

    it('omits item_schema_version when the custom flow definition has no version key', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: { versionName: '3.0.0', definition: 'components: []' },
        }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
      });
    });

    it('omits flow list fields when the definition is an empty string', () => {
      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: { versionName: '3.0.0', definition: '' },
        }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
      });
    });

    it('filters out blank tool and component values before joining', () => {
      const definition = `
components:
  - type: AgentComponent
    toolset:
      - read_file
      - ''
  - tool_name: edit_file
`;

      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: { versionName: '3.0.0', definition },
        }),
      ).toEqual({
        item_type: 'custom_flow',
        custom_item_id: 7,
        item_version: '3.0.0',
        tools: 'read_file,edit_file',
        components: 'AgentComponent',
      });
    });
  });

  describe('error handling', () => {
    const malformedVersion = { versionName: '3.0.0', definition: 'components: not-a-list' };

    it('reports the error to Sentry', () => {
      jest.replaceProperty(process.env, 'NODE_ENV', 'production');

      buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), { version: malformedVersion });

      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      expect(Sentry.captureException).toHaveBeenCalledWith(
        expect.any(Error),
        expect.objectContaining({
          extra: expect.objectContaining({
            item_type: 'FLOW',
            item_id: 'gid://gitlab/Ai::Catalog::Item/7',
            version_name: '3.0.0',
          }),
        }),
      );
    });

    it('returns an empty object in production so a bug cannot break the page', () => {
      jest.replaceProperty(process.env, 'NODE_ENV', 'production');

      expect(
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: malformedVersion,
        }),
      ).toEqual({});
    });

    it('re-raises outside production to surface the bug in development and tests', () => {
      jest.replaceProperty(process.env, 'NODE_ENV', 'development');

      expect(() =>
        buildAiCatalogEventProperties(baseItem({ itemType: 'FLOW' }), {
          version: malformedVersion,
        }),
      ).toThrow();
      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
    });

    it('reports an underivable item type to Sentry and returns an empty object in production', () => {
      jest.replaceProperty(process.env, 'NODE_ENV', 'production');

      expect(buildAiCatalogEventProperties(baseItem({ itemType: 'SOMETHING_ELSE' }))).toEqual({});

      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      expect(Sentry.captureException).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Unable to derive AI Catalog item_type from itemType: SOMETHING_ELSE',
        }),
        expect.objectContaining({
          extra: expect.objectContaining({ item_type: 'SOMETHING_ELSE' }),
        }),
      );
    });
  });
});
