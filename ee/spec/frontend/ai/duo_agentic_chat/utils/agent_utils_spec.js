import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  catalogAgentsFromResponse,
  validateAgentExists,
  prepareAgentSelection,
} from 'ee/ai/duo_agentic_chat/utils/agent_utils';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('agent_utils', () => {
  describe('catalogAgentsFromResponse', () => {
    const validNode = {
      id: 'consumer-1',
      pinnedVersionPrefix: '1.0.0',
      pinnedItemVersion: { id: 'version-1' },
      item: { id: 'agent-1', name: 'Agent One', description: 'Works fine' },
    };

    const nullPinnedNode = {
      id: 'consumer-2',
      pinnedVersionPrefix: '1.2.3',
      pinnedItemVersion: null,
      item: { id: 'agent-2', name: 'Broken Agent', description: 'Missing version' },
    };

    describe('when all nodes have pinnedItemVersion', () => {
      it('maps nodes to agents with pinnedItemVersionId', () => {
        const data = { aiCatalogConfiguredItems: { nodes: [validNode] } };

        expect(catalogAgentsFromResponse(data)).toEqual([
          {
            ...validNode.item,
            pinnedItemVersionId: 'version-1',
            pinnedItemVersion: validNode.pinnedItemVersion,
          },
        ]);
      });

      it('does not call Sentry', () => {
        const data = { aiCatalogConfiguredItems: { nodes: [validNode] } };
        catalogAgentsFromResponse(data);

        expect(Sentry.captureMessage).not.toHaveBeenCalled();
      });
    });

    describe('when a node has null pinnedItemVersion', () => {
      it('filters out the node with null pinnedItemVersion', () => {
        const data = { aiCatalogConfiguredItems: { nodes: [validNode, nullPinnedNode] } };

        expect(catalogAgentsFromResponse(data)).toEqual([
          {
            ...validNode.item,
            pinnedItemVersionId: 'version-1',
            pinnedItemVersion: validNode.pinnedItemVersion,
          },
        ]);
      });

      it('reports to Sentry with consumerId, itemId, pinnedVersionPrefix and totalNodes', () => {
        const data = { aiCatalogConfiguredItems: { nodes: [validNode, nullPinnedNode] } };
        catalogAgentsFromResponse(data);

        expect(Sentry.captureMessage).toHaveBeenCalledWith(
          'getConfiguredAgents: nodes with null pinnedItemVersion',
          {
            level: 'warning',
            extra: {
              affectedConsumers: [
                {
                  consumerId: nullPinnedNode.id,
                  itemId: nullPinnedNode.item.id,
                  pinnedVersionPrefix: nullPinnedNode.pinnedVersionPrefix,
                },
              ],
              totalNodes: 2,
            },
            fingerprint: ['workflow-catalog', 'pinned-version-null'],
          },
        );
      });
    });
  });

  describe('validateAgentExists', () => {
    const mockCatalogAgents = [
      {
        name: 'Test Agent 1',
        pinnedItemVersionId: 'version-123',
      },
      {
        name: 'Test Agent 2',
        pinnedItemVersionId: 'version-789',
      },
    ];

    describe('when no agent version ID is provided', () => {
      it('returns available with no error', () => {
        const result = validateAgentExists(null, mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: true,
          errorMessage: '',
        });
      });
    });

    describe('when agent version exists in catalog', () => {
      it('returns available with no error', () => {
        const result = validateAgentExists('version-123', mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: true,
          errorMessage: '',
        });
      });
    });

    describe('when agent version does not exist in catalog', () => {
      it('returns not available with error message', () => {
        const result = validateAgentExists('version-999', mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when catalog agents is empty', () => {
      it('returns not available with error message', () => {
        const result = validateAgentExists('version-123', []);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when agent has another pinned version', () => {
      it('returns not available with error message', () => {
        const agentsWithDifferentVersion = [
          {
            name: 'Test Agent',
            pinnedItemVersionId: 'version-456',
          },
        ];

        const result = validateAgentExists('version-123', agentsWithDifferentVersion);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when catalogAgents is null or undefined', () => {
      it('returns not available with error message for null', () => {
        const result = validateAgentExists('version-123', null);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });

      it('returns not available with error message for undefined', () => {
        const result = validateAgentExists('version-123', undefined);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });
  });

  describe('prepareAgentSelection', () => {
    describe('when reuseAgent is true', () => {
      it('returns null to keep current agent', () => {
        const agent = { id: 'agent-123' };

        const result = prepareAgentSelection(agent, true);

        expect(result).toBeNull();
      });
    });

    describe('when foundational agent is selected', () => {
      it('returns foundational agent state', () => {
        const agent = {
          id: 'foundational-agent-123',
          name: 'Code Generation Agent',
          foundational: true,
        };

        const result = prepareAgentSelection(agent, false);

        expect(result).toEqual({
          aiCatalogItemVersionId: '',
          selectedFoundationalAgent: agent,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });

    describe('when custom catalog agent is selected', () => {
      it('returns agent data with pinned version', () => {
        const agent = {
          id: 'agent-123',
          pinnedItemVersionId: 'version-2',
        };

        const result = prepareAgentSelection(agent, false);

        expect(result).toEqual({
          aiCatalogItemVersionId: 'version-2',
          selectedFoundationalAgent: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });

    describe('when no agent is selected', () => {
      it('returns default agent state for undefined', () => {
        const result = prepareAgentSelection(undefined, false);
        expect(result).toEqual({
          aiCatalogItemVersionId: '',
          selectedFoundationalAgent: null,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });

      it('returns default agent state for null', () => {
        const result = prepareAgentSelection(null, false);
        expect(result).toEqual({
          aiCatalogItemVersionId: '',
          selectedFoundationalAgent: null,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });
  });
});
