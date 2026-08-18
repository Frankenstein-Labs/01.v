import { toolDenialTransformer } from 'ee/ai/duo_agentic_chat/transformers/tool_denial_transformer';

const makeApprovalRequest = (overrides = {}) => ({
  message_id: 'req-1',
  message_type: 'request',
  role: 'assistant',
  status: 'success',
  content: 'Tool create_commit requires approval. Please confirm if you want to proceed.',
  tool_info: {
    name: 'create_commit',
    args: { commit_message: 'Update README' },
  },
  ...overrides,
});

const makeExecutedTool = (overrides = {}) => ({
  message_id: 'tool-1',
  message_type: 'tool',
  role: 'tool',
  status: 'success',
  content: 'Created commit',
  tool_info: {
    name: 'create_commit',
    args: { commit_message: 'Update README' },
  },
  ...overrides,
});

const makeAgentMessage = (overrides = {}) => ({
  message_id: 'agent-1',
  message_type: 'agent',
  role: 'assistant',
  content: 'Tool execution denied, proceeding with alternative approach',
  tool_info: null,
  ...overrides,
});

describe('toolDenialTransformer', () => {
  describe('denied approval requests', () => {
    it('converts a denied request into a cancelled request card', () => {
      const request = makeApprovalRequest();
      const result = toolDenialTransformer([request, makeAgentMessage()]);

      expect(result[0]).toMatchObject({
        message_id: 'req-1',
        message_type: 'request',
        role: 'assistant',
        status: 'cancelled',
        tool_info: { name: 'create_commit' },
      });
    });

    it('preserves the original tool_info and content on the converted message', () => {
      const request = makeApprovalRequest();
      const [converted] = toolDenialTransformer([request, makeAgentMessage()]);

      expect(converted.tool_info).toEqual(request.tool_info);
      expect(converted.content).toBe(request.content);
    });

    it('converts each denied request when several were denied', () => {
      const result = toolDenialTransformer([
        makeApprovalRequest({ message_id: 'req-1' }),
        makeApprovalRequest({ message_id: 'req-2' }),
        makeAgentMessage(),
      ]);

      expect(result[0].status).toBe('cancelled');
      expect(result[1].status).toBe('cancelled');
    });
  });

  describe('approved approval requests', () => {
    it('leaves a request untouched when a matching executed tool follows it', () => {
      const request = makeApprovalRequest();
      const result = toolDenialTransformer([request, makeExecutedTool(), makeAgentMessage()]);

      expect(result[0]).toBe(request);
      expect(result[0].message_type).toBe('request');
      expect(result[0].status).toBe('success');
    });

    it('claims each executed tool only once so a later same-tool request is still denied', () => {
      const approvedRequest = makeApprovalRequest({ message_id: 'req-1' });
      const deniedRequest = makeApprovalRequest({ message_id: 'req-2' });

      const result = toolDenialTransformer([
        approvedRequest,
        makeExecutedTool(),
        deniedRequest,
        makeAgentMessage(),
      ]);

      expect(result[0].message_type).toBe('request');
      expect(result[2].message_type).toBe('request');
      expect(result[2].status).toBe('cancelled');
    });

    it('matches the executed tool by name even when args differ', () => {
      const request = makeApprovalRequest();
      const executedWithDifferentArgs = makeExecutedTool({
        tool_info: { name: 'create_commit', args: { commit_message: 'normalized' } },
      });

      const result = toolDenialTransformer([request, executedWithDifferentArgs]);

      expect(result[0].message_type).toBe('request');
    });
  });

  describe('pending approval requests', () => {
    it('leaves a trailing pending request untouched', () => {
      const request = makeApprovalRequest();
      const result = toolDenialTransformer([makeAgentMessage(), request]);

      expect(result[1]).toBe(request);
      expect(result[1].message_type).toBe('request');
    });

    it('leaves a trailing run of multiple pending requests untouched', () => {
      const result = toolDenialTransformer([
        makeApprovalRequest({ message_id: 'req-1' }),
        makeApprovalRequest({ message_id: 'req-2' }),
      ]);

      expect(result[0].message_type).toBe('request');
      expect(result[1].message_type).toBe('request');
    });
  });

  describe('non-approval messages', () => {
    it('leaves messages without tool_info untouched', () => {
      const agent = makeAgentMessage();
      const result = toolDenialTransformer([agent]);

      expect(result[0]).toBe(agent);
    });

    it('returns an empty array unchanged', () => {
      expect(toolDenialTransformer([])).toEqual([]);
    });
  });
});
