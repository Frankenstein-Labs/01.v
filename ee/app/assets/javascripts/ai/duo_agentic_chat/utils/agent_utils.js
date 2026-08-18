import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { AI_CATALOG_TYPE_AGENT } from 'ee/ai/catalog/constants';

export function catalogAgentsFromResponse(data) {
  const nodes = data?.aiCatalogConfiguredItems?.nodes || [];
  const invalid = nodes.filter((node) => !node.pinnedItemVersion);

  if (invalid.length > 0) {
    Sentry.captureMessage('getConfiguredAgents: nodes with null pinnedItemVersion', {
      level: 'warning',
      fingerprint: ['workflow-catalog', 'pinned-version-null'],
      extra: {
        affectedConsumers: invalid.map((node) => ({
          consumerId: node.id,
          itemId: node.item?.id,
          pinnedVersionPrefix: node.pinnedVersionPrefix,
        })),
        totalNodes: nodes.length,
      },
    });
  }

  return nodes
    .filter((node) => node.pinnedItemVersion)
    .map((node) => ({
      ...node.item,
      pinnedItemVersionId: node.pinnedItemVersion.id,
      pinnedItemVersion: node.pinnedItemVersion,
    }));
}

export function validateAgentExists(aiCatalogItemVersionId, catalogAgents) {
  // No specific agent selected - using default agent, which is always available
  if (!aiCatalogItemVersionId) {
    return {
      isAvailable: true,
      errorMessage: '',
    };
  }

  // Check if the agent version exists in the catalog
  const agentExists = catalogAgents?.some(
    (agent) => agent.pinnedItemVersionId === aiCatalogItemVersionId,
  );

  if (!agentExists) {
    return {
      isAvailable: false,
      errorMessage: s__(
        'DuoAgenticChat|The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      ),
    };
  }

  return {
    isAvailable: true,
    errorMessage: '',
  };
}

export function prepareAgentSelection(agent, reuseAgent) {
  // Keep current agent when reusing
  if (reuseAgent) {
    return null;
  }

  const newParams = {
    aiCatalogItemVersionId: '',
    selectedFoundationalAgent: null,
    isChatAvailable: true,
    agentDeletedError: '',
  };

  // Select foundational agent
  if (agent?.foundational) {
    return {
      ...newParams,
      agentConfig: null,
      selectedFoundationalAgent: agent,
    };
  }

  // Select custom catalog agent
  if (agent?.id) {
    if (!agent.pinnedItemVersionId) {
      return {
        ...newParams,
        agentConfig: null,
      };
    }
    return {
      ...newParams,
      aiCatalogItemVersionId: agent.pinnedItemVersionId,
    };
  }

  // Reset to default agent
  return {
    ...newParams,
    agentConfig: null,
  };
}

// Maps foundational agent data to what buildAiCatalogEventProperties expects
export function foundationalAgentToItemAndVersion(agent) {
  if (!agent) {
    return { item: null, version: null };
  }

  const versionName = agent.flowConfig?.flowVersion;

  return {
    item: {
      id: agent.id,
      itemType: AI_CATALOG_TYPE_AGENT,
      foundational: true,
      foundationalAgentReference: agent.reference,
      latestVersion: { versionName },
    },
    version: {
      versionName,
      schemaVersion: agent.version,
      tools: { nodes: (agent.tools || []).map((tool) => ({ name: tool.name })) },
    },
  };
}
