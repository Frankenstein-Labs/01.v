import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import {
  MOCK_ASSISTANT_MESSAGES,
  MOCK_SINGLE_GENERIC_MESSAGE,
  MOCK_MULTIPLE_USER_MESSAGES,
  MOCK_USER_MESSAGE_WITH_PROPERTIES,
  MOCK_PARSE_WORKFLOW_RESPONSE,
  MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE,
  MOCK_PARSE_WORKFLOW_WITH_CHECKPOINT_RESPONSE,
} from './mock_data';

describe('WorkflowUtils', () => {
  describe('parseWorkflowData', () => {
    it('returns null when there are no workflow nodes', () => {
      const result = WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE);

      expect(result).toBeNull();
    });

    it('returns the latestCheckpoint from the first workflow node', () => {
      const result = WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_RESPONSE);

      expect(result.workflowGoal).toBe('Test goal');
      expect(result.workflowStatus).toBe('RUNNING');
      expect(result.duoMessages).toHaveLength(1);
    });

    it('returns null when the workflow has no latestCheckpoint', () => {
      const result = WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_WITH_CHECKPOINT_RESPONSE);

      expect(result).toBeNull();
    });
  });

  describe('parseWorkflowStatus', () => {
    it('returns null when there are no workflow nodes', () => {
      expect(WorkflowUtils.parseWorkflowStatus(MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE)).toBeNull();
    });

    it('returns null for an empty response object', () => {
      expect(WorkflowUtils.parseWorkflowStatus({})).toBeNull();
    });

    it('returns the status of the first workflow node', () => {
      expect(WorkflowUtils.parseWorkflowStatus(MOCK_PARSE_WORKFLOW_RESPONSE)).toBe('RUNNING');
    });

    it('returns the status even when the workflow has no latestCheckpoint', () => {
      expect(WorkflowUtils.parseWorkflowStatus(MOCK_PARSE_WORKFLOW_WITH_CHECKPOINT_RESPONSE)).toBe(
        'CREATED',
      );
    });
  });

  describe('normalizeDuoMessages', () => {
    it('converts camelCase GraphQL fields to snake_case', () => {
      const duoMessages = [
        {
          content: 'Hello',
          messageType: 'agent',
          toolInfo: '{"name":"tool"}',
          messageId: 'executor-msg-1',
          correlationId: 'client-corr-1',
          role: 'assistant',
          status: null,
          timestamp: '2025-07-25T14:30:00Z',
        },
      ];

      const result = WorkflowUtils.normalizeDuoMessages(duoMessages);

      expect(result[0]).toEqual({
        content: 'Hello',
        message_type: 'agent',
        tool_info: { name: 'tool' },
        message_id: 'executor-msg-1',
        correlation_id: 'client-corr-1',
        role: 'assistant',
        status: null,
        timestamp: '2025-07-25T14:30:00Z',
      });
    });

    it('returns an empty array for empty input', () => {
      expect(WorkflowUtils.normalizeDuoMessages([])).toEqual([]);
    });
  });

  describe('findLatestTodoToolInfo', () => {
    const todoToolInfo = (todos) => ({
      name: 'todo_write',
      args: { todos },
    });

    const otherToolInfo = {
      name: 'read_file',
      args: { path: 'foo.rb' },
    };

    describe('when the messages array is empty', () => {
      let result;

      beforeEach(() => {
        result = WorkflowUtils.findLatestTodoToolInfo([]);
      });

      it('returns null', () => {
        expect(result).toBeNull();
      });
    });

    describe('when no message has a todo_write tool_info', () => {
      let result;

      beforeEach(() => {
        const messages = [{ tool_info: otherToolInfo }, { tool_info: { name: 'grep', args: {} } }];

        result = WorkflowUtils.findLatestTodoToolInfo(messages);
      });

      it('returns null', () => {
        expect(result).toBeNull();
      });
    });

    describe('when a single todo_write message has todos', () => {
      const expected = todoToolInfo([{ status: 'pending', description: 'one' }]);
      let result;

      beforeEach(() => {
        const messages = [{ tool_info: otherToolInfo }, { tool_info: expected }];

        result = WorkflowUtils.findLatestTodoToolInfo(messages);
      });

      it('returns its tool_info', () => {
        expect(result).toBe(expected);
      });
    });

    describe('when multiple todo_write messages are present', () => {
      const oldest = todoToolInfo([{ status: 'pending', description: 'old' }]);
      const latest = todoToolInfo([{ status: 'in_progress', description: 'new' }]);
      let result;

      beforeEach(() => {
        const messages = [
          { tool_info: oldest },
          { tool_info: otherToolInfo },
          { tool_info: latest },
        ];

        result = WorkflowUtils.findLatestTodoToolInfo(messages);
      });

      it('returns the latest tool_info', () => {
        expect(result).toBe(latest);
      });
    });

    describe('when the latest todo_write has an empty todos array', () => {
      let result;

      beforeEach(() => {
        const messages = [{ tool_info: todoToolInfo([]) }];

        result = WorkflowUtils.findLatestTodoToolInfo(messages);
      });

      it('returns null', () => {
        expect(result).toBeNull();
      });
    });

    describe('when some messages are missing tool_info', () => {
      const expected = todoToolInfo([{ status: 'completed', description: 'done' }]);
      let result;

      beforeEach(() => {
        const messages = [{}, { tool_info: null }, { tool_info: expected }];

        result = WorkflowUtils.findLatestTodoToolInfo(messages);
      });

      it('skips them and returns the latest todo_write tool_info', () => {
        expect(result).toBe(expected);
      });
    });
  });

  describe('transformChatMessages', () => {
    it('maps agent and request message types to assistant role', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_ASSISTANT_MESSAGES);

      expect(result[0].role).toBe(GENIE_CHAT_MODEL_ROLES.assistant);
      expect(result[1].role).toBe(GENIE_CHAT_MODEL_ROLES.assistant);
    });

    it('preserves original message_type for non-agent/request messages', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_SINGLE_GENERIC_MESSAGE);
      expect(result[0].role).toBe('generic');
    });

    it('preserves all original message properties', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_USER_MESSAGE_WITH_PROPERTIES);

      expect(result[0]).toEqual({
        ...MOCK_USER_MESSAGE_WITH_PROPERTIES[0],
        id: 'msg-7',
        requestId: 'msg-7',
        role: 'user',
      });
    });

    it('sets requestId to message_id for each message', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_MULTIPLE_USER_MESSAGES);

      expect(result[0].requestId).toBe('msg-4');
      expect(result[1].requestId).toBe('msg-5');
      expect(result[2].requestId).toBe('msg-6');
    });

    it('excludes orbit_context items from contextItems but keeps other additional_context', () => {
      const messages = [
        {
          message_type: 'user',
          message_id: 'msg-8',
          content: 'Test',
          additional_context: [
            { category: 'orbit_context', content: '{"orbit_enabled":false}', metadata: '{}' },
            { category: 'repository', content: 'page', metadata: { title: 'Current page' } },
          ],
        },
      ];

      const result = WorkflowUtils.transformChatMessages(messages);
      const { contextItems } = result[0].extras;

      expect(contextItems).toHaveLength(1);
      expect(contextItems[0].category).toBe('repository');
    });

    it('sets id to message_id for each message', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_MULTIPLE_USER_MESSAGES);

      expect(result[0].id).toBe('msg-4');
      expect(result[1].id).toBe('msg-5');
      expect(result[2].id).toBe('msg-6');
    });

    it('excludes permissions_form_context items from the visible contextItems', () => {
      const messages = [
        {
          message_type: 'user',
          message_id: 'msg-9',
          content: 'Test',
          additional_context: [
            {
              category: 'permissions_form_context',
              content: '{"namespace":[],"user":[],"instance":[],"access":""}',
              metadata: '{}',
            },
            { category: 'repository', content: 'page', metadata: { title: 'Current page' } },
          ],
        },
      ];

      const result = WorkflowUtils.transformChatMessages(messages);
      const { contextItems } = result[0].extras;

      expect(contextItems).toHaveLength(1);
      expect(contextItems[0].category).toBe('repository');
    });

    describe('with alternatives', () => {
      const mockAlternatives = [
        {
          user_message: { message_id: 'alt-user-1', content: 'question' },
          agent_responses: [
            { message_id: 'alt-agent-1', content: 'first response', message_type: 'agent' },
          ],
        },
        {
          user_message: { message_id: 'alt-user-2', content: 'question' },
          agent_responses: [
            { message_id: 'alt-agent-2', content: 'second response', message_type: 'agent' },
          ],
        },
      ];

      it('transforms alternatives on messages when present', () => {
        const messages = [
          {
            message_type: 'agent',
            message_id: 'msg-with-alts',
            content: 'current response',
            alternatives: mockAlternatives,
          },
        ];

        const result = WorkflowUtils.transformChatMessages(messages);

        expect(result[0].alternatives).toHaveLength(2);
        expect(result[0].alternatives[0].agent_responses[0].id).toBe('alt-agent-1');
        expect(result[0].alternatives[0].agent_responses[0].role).toBe(
          GENIE_CHAT_MODEL_ROLES.assistant,
        );
      });

      it('does not add alternatives property when message has no alternatives', () => {
        const messages = [
          {
            message_type: 'agent',
            message_id: 'msg-no-alts',
            content: 'response without alternatives',
          },
        ];

        const result = WorkflowUtils.transformChatMessages(messages);

        expect(result[0]).not.toHaveProperty('alternatives');
      });

      it('does not add alternatives property when alternatives array is empty', () => {
        const messages = [
          {
            message_type: 'agent',
            message_id: 'msg-empty-alts',
            content: 'response with empty alternatives',
            alternatives: [],
          },
        ];

        const result = WorkflowUtils.transformChatMessages(messages);

        expect(result[0]).not.toHaveProperty('alternatives');
      });
    });
  });

  describe('transformAlternatives', () => {
    it('returns empty array when alternatives is null', () => {
      expect(WorkflowUtils.transformAlternatives(null)).toEqual([]);
    });

    it('returns empty array when alternatives is undefined', () => {
      expect(WorkflowUtils.transformAlternatives(undefined)).toEqual([]);
    });

    it('returns empty array when alternatives is empty', () => {
      expect(WorkflowUtils.transformAlternatives([])).toEqual([]);
    });

    it('transforms alternatives with proper structure', () => {
      const alternatives = [
        {
          user_message: { message_id: 'u1', content: 'q1' },
          agent_responses: [{ message_id: 'a1', content: 'r1' }],
        },
      ];

      const result = WorkflowUtils.transformAlternatives(alternatives);

      expect(result).toHaveLength(1);
      expect(result[0].user_message).toEqual({ message_id: 'u1', content: 'q1' });
      expect(result[0].agent_responses[0]).toMatchObject({
        id: 'a1',
        message_id: 'a1',
        content: 'r1',
        role: GENIE_CHAT_MODEL_ROLES.assistant,
        requestId: 'a1',
      });
    });

    it('handles alternatives with missing agent_responses', () => {
      const alternatives = [{ user_message: { message_id: 'u1' }, agent_responses: null }];

      const result = WorkflowUtils.transformAlternatives(alternatives);

      expect(result[0].agent_responses).toEqual([]);
    });
  });
});
