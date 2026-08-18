import {
  buildWebsocketUrl,
  buildStartRequest,
  processWorkflowMessage,
} from 'ee/ai/duo_agentic_chat/websocket/workflow_utils';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import * as websocketUtils from '~/lib/utils/websocket_utils';

jest.mock('~/lib/utils/websocket_utils');

describe('workflow_utils', () => {
  describe('buildWebsocketUrl', () => {
    beforeEach(() => {
      window.gon = { api_version: 'v4', relative_url_root: '' };
    });

    describe('when relative_url_root is not empty', () => {
      it('prefixes the URL with the relative_url_root', () => {
        window.gon = { api_version: 'v4', relative_url_root: '/gitlab' };

        const url = buildWebsocketUrl({});

        expect(url).toBe(
          '/gitlab/api/v4/ai/duo_workflows/ws?workflow_definition=chat&client_type=browser',
        );
      });
    });

    describe('when no parameters are provided', () => {
      it('builds basic URL with default workflow_definition', () => {
        const url = buildWebsocketUrl({});

        expect(url).toBe(
          '/api/v4/ai/duo_workflows/ws?workflow_definition=chat&client_type=browser',
        );
      });
    });

    describe('when rootNamespaceId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          rootNamespaceId: 'gid://gitlab/Group/123',
        });

        expect(url).toContain('root_namespace_id=123');
      });
    });

    describe('when namespaceId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          namespaceId: 'gid://gitlab/Group/456',
        });

        expect(url).toContain('namespace_id=456');
      });
    });

    describe('when projectId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          projectId: 'gid://gitlab/Project/789',
        });

        expect(url).toContain('project_id=789');
      });
    });

    describe('when user model selection is enabled', () => {
      describe('when current model is not the default', () => {
        it('includes user_selected_model_identifier', () => {
          const url = buildWebsocketUrl({
            rootNamespaceId: 'gid://gitlab/Group/123',
            userModelSelectionEnabled: true,
            currentModel: { value: 'custom-model' },
            defaultModel: { value: GITLAB_DEFAULT_MODEL },
          });

          expect(url).toContain('user_selected_model_identifier=custom-model');
        });
      });

      describe('when current model is the default', () => {
        it('does not include user_selected_model_identifier', () => {
          const url = buildWebsocketUrl({
            rootNamespaceId: 'gid://gitlab/Group/123',
            userModelSelectionEnabled: true,
            currentModel: { value: GITLAB_DEFAULT_MODEL },
            defaultModel: { value: GITLAB_DEFAULT_MODEL },
          });

          expect(url).not.toContain('user_selected_model_identifier');
        });
      });
    });

    describe('when multiple parameters are provided', () => {
      it('combines all parameters', () => {
        const url = buildWebsocketUrl({
          rootNamespaceId: 'gid://gitlab/Group/123',
          namespaceId: 'gid://gitlab/Group/456',
          projectId: 'gid://gitlab/Project/789',
        });

        expect(url).toContain('root_namespace_id=123');
        expect(url).toContain('namespace_id=456');
        expect(url).toContain('project_id=789');
      });
    });

    describe('when workflowDefinition is provided', () => {
      it('includes workflow_definition parameter', () => {
        const url = buildWebsocketUrl({
          workflowDefinition: 'software_development',
        });

        expect(url).toContain('workflow_definition=software_development');
      });
    });

    describe('when workflowDefinition is not provided', () => {
      it('defaults to chat workflow_definition', () => {
        const url = buildWebsocketUrl({});

        expect(url).toContain('workflow_definition=chat');
      });
    });

    describe('when aiCatalogItemVersionId is provided', () => {
      it('includes ai_catalog_item_version_id parameter', () => {
        const url = buildWebsocketUrl({
          aiCatalogItemVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/100',
        });

        expect(url).toContain('ai_catalog_item_version_id=100');
      });
    });

    describe('when aiCatalogItemVersionId is not provided', () => {
      it('does not include ai_catalog_item_version_id parameter', () => {
        const url = buildWebsocketUrl({});

        expect(url).not.toContain('ai_catalog_item_version_id');
      });
    });

    describe('when aiCatalogItemVersionId is null', () => {
      it('does not include ai_catalog_item_version_id parameter', () => {
        const url = buildWebsocketUrl({
          aiCatalogItemVersionId: null,
        });

        expect(url).not.toContain('ai_catalog_item_version_id');
      });
    });

    describe('when aiCatalogItemVersionId is empty string', () => {
      it('does not include ai_catalog_item_version_id parameter', () => {
        const url = buildWebsocketUrl({
          aiCatalogItemVersionId: '',
        });

        expect(url).not.toContain('ai_catalog_item_version_id');
      });
    });

    describe('when aiCatalogItemVersionId is malformed', () => {
      it('does not include ai_catalog_item_version_id parameter', () => {
        const url = buildWebsocketUrl({
          aiCatalogItemVersionId: 'invalid-gid',
        });

        expect(url).not.toContain('ai_catalog_item_version_id');
      });
    });

    describe('when workflowId is provided', () => {
      it('includes workflow_id parameter', () => {
        const url = buildWebsocketUrl({
          workflowId: '42',
        });

        expect(url).toContain('workflow_id=42');
      });
    });

    describe('when workflowId is not provided', () => {
      it('does not include workflow_id parameter', () => {
        const url = buildWebsocketUrl({});

        expect(url).not.toContain('workflow_id');
      });
    });

    describe('when workflowId is null', () => {
      it('does not include workflow_id parameter', () => {
        const url = buildWebsocketUrl({
          workflowId: null,
        });

        expect(url).not.toContain('workflow_id');
      });
    });

    describe('when workflowId is empty string', () => {
      it('does not include workflow_id parameter', () => {
        const url = buildWebsocketUrl({
          workflowId: '',
        });

        expect(url).not.toContain('workflow_id');
      });
    });
  });

  describe('buildStartRequest', () => {
    describe('when called with basic parameters', () => {
      it('builds start request with required fields', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
        });

        expect(request).toEqual({
          startRequest: {
            workflowID: '123',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            workflowMetadata: 'test metadata',
            clientCapabilities: [],
            goal: 'test goal',
            approval: {},
            useOrbit: true,
            regenerate: false,
          },
        });
      });
    });

    describe('when workflowDefinition is not null', () => {
      it('builds start request with required fields', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          workflowDefinition: 'agent/v1',
        });

        expect(request).toEqual({
          startRequest: {
            workflowID: '123',
            clientVersion: '1.0',
            workflowDefinition: 'agent/v1',
            workflowMetadata: 'test metadata',
            clientCapabilities: [],
            goal: 'test goal',
            approval: {},
            useOrbit: true,
            regenerate: false,
          },
        });
      });
    });

    describe('when additionalContext is provided', () => {
      it('includes additionalContext in request', () => {
        const additionalContext = [{ content: 'context data' }];
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          additionalContext,
        });

        expect(request.startRequest.additional_context).toEqual(additionalContext);
      });
    });

    describe('when agentConfig is provided', () => {
      it('includes flowConfig and schema version', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          agentConfig: 'version: my_version\ncomponents:\n  - name: test\n    type: agent',
        });

        expect(request.startRequest.flowConfig).toBeDefined();
        expect(request.startRequest.flowConfigSchemaVersion).toBe('my_version');
      });

      it('returns a plain object for flowConfig that can be transferred to a Web Worker via postMessage', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          agentConfig: 'version: my_version\ncomponents:\n  - name: test\n    type: agent',
        });

        // structured clone will throw a DataCloneError if flowConfig contains
        // non-serialisable values (e.g. a yaml Document instance with function properties)
        // eslint-disable-next-line no-restricted-globals -- structuredClone is required to asset `postMessage` transferability
        expect(() => structuredClone(request)).not.toThrow();
        expect(request.startRequest.flowConfig).toEqual(
          expect.objectContaining({ version: 'my_version' }),
        );
      });
    });

    describe('when flowConfig is provided', () => {
      it('includes flowConfigId, flowVersion and schema version when a schema version is present', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          flowConfig: {
            flowConfigId: 'agentic_chat',
            flowVersion: '1.0.0',
            flowConfigSchemaVersion: 'v1',
          },
        });

        expect(request.startRequest.flowConfigId).toBe('agentic_chat');
        expect(request.startRequest.flowVersion).toBe('1.0.0');
        expect(request.startRequest.flowConfigSchemaVersion).toBe('v1');
      });

      it('omits the flow config when no schema version is present', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          flowConfig: {
            flowConfigId: 'chat',
            flowVersion: '^1.0.0',
            flowConfigSchemaVersion: null,
          },
        });

        expect(request.startRequest.flowConfigId).toBeUndefined();
        expect(request.startRequest.flowVersion).toBeUndefined();
        expect(request.startRequest.flowConfigSchemaVersion).toBeUndefined();
      });
    });

    describe('when approval is provided', () => {
      it('includes approval in request', () => {
        const approval = { approved: true };
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          approval,
        });

        expect(request.startRequest.approval).toEqual(approval);
      });
    });

    describe('when clientCapabilities is provided', () => {
      it('includes clientCapabilities in request', () => {
        const clientCapabilities = ['incremental_streaming'];
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          clientCapabilities,
        });

        expect(request.startRequest.clientCapabilities).toEqual(clientCapabilities);
      });
    });

    describe('when clientCapabilities is not provided', () => {
      it('defaults to empty array', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
        });

        expect(request.startRequest.clientCapabilities).toEqual([]);
      });
    });

    describe('when orbitEnabled is provided', () => {
      it('includes useOrbit: true in request when orbitEnabled is true', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          orbitEnabled: true,
        });

        expect(request.startRequest.useOrbit).toBe(true);
      });

      it('includes useOrbit: false in request when orbitEnabled is false', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          orbitEnabled: false,
        });

        expect(request.startRequest.useOrbit).toBe(false);
      });
    });

    describe('when orbitEnabled is not provided', () => {
      it('defaults useOrbit to true', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
        });

        expect(request.startRequest.useOrbit).toBe(true);
      });
    });

    describe('isRetry (mapped to regenerate)', () => {
      it('defaults regenerate to false when isRetry is not provided', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
        });

        expect(request.startRequest.regenerate).toBe(false);
      });

      it('sets regenerate: true when isRetry: true is passed', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          isRetry: true,
        });

        expect(request.startRequest.regenerate).toBe(true);
      });
    });
  });

  describe('processWorkflowMessage', () => {
    const mockEvent = { data: 'test' };

    beforeEach(() => {
      jest.clearAllMocks();
    });

    describe('when action is null', () => {
      it('returns null', async () => {
        websocketUtils.parseMessage.mockResolvedValue(null);

        const result = await processWorkflowMessage(mockEvent, null);

        expect(result).toBeNull();
      });
    });

    describe('when action has no newCheckpoint', () => {
      it('returns null', async () => {
        websocketUtils.parseMessage.mockResolvedValue({ otherData: 'value' });

        const result = await processWorkflowMessage(mockEvent, null);

        expect(result).toBeNull();
      });
    });

    describe('when checkpoint JSON is malformed', () => {
      it('returns null for invalid JSON', async () => {
        websocketUtils.parseMessage.mockResolvedValue({
          newCheckpoint: {
            checkpoint: 'not valid json{{{',
            status: 'running',
            goal: 'test goal',
          },
        });

        const result = await processWorkflowMessage(mockEvent, null);

        expect(result).toBeNull();
      });
    });

    describe('when checkpoint structure is incomplete', () => {
      it.each`
        desc                        | checkpoint
        ${'missing channel_values'} | ${{ other_key: {} }}
        ${'missing ui_chat_log'}    | ${{ channel_values: {} }}
        ${'channel_values is null'} | ${{ channel_values: null }}
        ${'empty object'}           | ${{}}
      `('returns null when $desc', async ({ checkpoint }) => {
        websocketUtils.parseMessage.mockResolvedValue({
          newCheckpoint: {
            checkpoint: JSON.stringify(checkpoint),
            status: 'running',
            goal: 'test goal',
          },
        });

        const result = await processWorkflowMessage(mockEvent, null);

        expect(result).toBeNull();
      });
    });

    describe('when valid workflow message is received', () => {
      it('processes and returns transformed data', async () => {
        const mockMessages = [
          { content: 'test message', role: 'assistant', message_type: 'agent' },
        ];
        const mockCheckpoint = {
          channel_values: {
            ui_chat_log: mockMessages,
          },
        };

        websocketUtils.parseMessage.mockResolvedValue({
          newCheckpoint: {
            checkpoint: JSON.stringify(mockCheckpoint),
            status: 'running',
            goal: 'test goal',
          },
        });

        const result = await processWorkflowMessage(mockEvent, null);

        expect(result).toEqual({
          messages: [
            {
              ...mockMessages[0],
              id: mockMessages[0].message_id,
              requestId: mockMessages[0].message_id,
            },
          ],
          status: 'running',
          goal: 'test goal',
          lastProcessedMessageId: mockMessages[0].message_id,
        });
      });

      it('correctly sets message IDs on the sequential messages', async () => {
        const mockMessageFirstPass = {
          content: 'Hello',
          role: 'user',
          message_type: 'user',
          message_id: 0,
        };
        const mockMessageSecondPass = {
          content: 'Hello yourself',
          role: 'assistant',
          message_type: 'agent',
          message_id: 1,
        };
        const mockMessageThirdPass = {
          content: 'Bummer',
          role: 'tool',
          message_type: 'tool',
          message_id: 2,
        };

        const mockCheckpoint = (messages) => {
          return {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: messages,
              },
            }),
            status: 'running',
            goal: 'test goal',
          };
        };

        // We build the realistic iterative checkpoint events behavior
        websocketUtils.parseMessage
          .mockResolvedValueOnce({
            newCheckpoint: mockCheckpoint([mockMessageFirstPass]),
          })
          .mockResolvedValueOnce({
            newCheckpoint: mockCheckpoint([mockMessageFirstPass, mockMessageSecondPass]),
          })
          .mockResolvedValueOnce({
            newCheckpoint: mockCheckpoint([
              mockMessageFirstPass,
              mockMessageSecondPass,
              mockMessageThirdPass,
            ]),
          });

        // First pass - user message is included
        let result = await processWorkflowMessage(mockEvent, null);
        let { lastProcessedMessageId } = result;
        expect(result).toEqual({
          messages: [
            {
              ...mockMessageFirstPass,
              id: mockMessageFirstPass.message_id,
              requestId: mockMessageFirstPass.message_id,
            },
          ],
          status: 'running',
          goal: 'test goal',
          lastProcessedMessageId: mockMessageFirstPass.message_id,
        });

        // Second pass - returns all messages from the last processed message onwards
        result = await processWorkflowMessage(mockEvent, lastProcessedMessageId);
        ({ lastProcessedMessageId } = result);
        expect(result).toEqual({
          messages: [
            {
              ...mockMessageFirstPass,
              id: mockMessageFirstPass.message_id,
              requestId: mockMessageFirstPass.message_id,
            },
            {
              ...mockMessageSecondPass,
              id: mockMessageSecondPass.message_id,
              requestId: mockMessageSecondPass.message_id,
            },
          ],
          status: 'running',
          goal: 'test goal',
          lastProcessedMessageId: mockMessageSecondPass.message_id,
        });

        // Third pass - returns messages from the last processed message onwards (agent + tool)
        result = await processWorkflowMessage(mockEvent, lastProcessedMessageId);
        expect(result).toEqual({
          messages: [
            {
              ...mockMessageSecondPass,
              id: mockMessageSecondPass.message_id,
              requestId: mockMessageSecondPass.message_id,
            },
            {
              ...mockMessageThirdPass,
              id: mockMessageThirdPass.message_id,
              requestId: mockMessageThirdPass.message_id,
            },
          ],
          status: 'running',
          goal: 'test goal',
          lastProcessedMessageId: mockMessageThirdPass.message_id,
        });
      });
    });
  });
});
