import {
  SystemContextManager,
  getContextInjectionState,
} from 'ee/ai/duo_agentic_chat/context/system_context_manager';
import {
  AI_CONTEXT_ID_PAGE_CONTEXT,
  AI_CONTEXT_ID_AGENT_MD,
  AI_CONTEXT_ID_CHAT_RULE,
} from 'ee/ai/constants';

describe('getContextInjectionState', () => {
  beforeEach(() => {
    delete window.location;
    window.location = { pathname: '/test/path' };
  });

  it('extracts context from user messages', () => {
    const messages = [
      {
        message_type: 'user',
        additional_context: [
          { id: AI_CONTEXT_ID_AGENT_MD, metadata: { oid: 'abc123' } },
          { id: AI_CONTEXT_ID_CHAT_RULE, metadata: { oid: 'def456' } },
        ],
      },
    ];

    const state = getContextInjectionState(messages, 'group/project');

    expect(state[AI_CONTEXT_ID_AGENT_MD].oid).toBe('abc123');
    expect(state[AI_CONTEXT_ID_CHAT_RULE].oid).toBe('def456');
  });

  it('detects page and project changes', () => {
    const messages = [
      {
        message_type: 'user',
        additional_context: [
          {
            id: AI_CONTEXT_ID_PAGE_CONTEXT,
            metadata: { pagePath: '/old', projectPath: 'old' },
          },
        ],
      },
    ];

    const state = getContextInjectionState(messages, 'new');

    expect(state[AI_CONTEXT_ID_PAGE_CONTEXT].pageChanged).toBe(true);
    expect(state[AI_CONTEXT_ID_PAGE_CONTEXT].projectChanged).toBe(true);
  });

  it('ignores non-user messages and sets defaults', () => {
    const messages = [{ message_type: 'assistant', additional_context: [{ id: 'x' }] }];

    const state = getContextInjectionState(messages, 'project');

    expect(state.x).toBeUndefined();
    expect(state[AI_CONTEXT_ID_PAGE_CONTEXT]).toBeDefined();
  });

  it('stops processing after finding all context items', () => {
    const messages = [
      {
        message_type: 'user',
        additional_context: [
          { id: AI_CONTEXT_ID_PAGE_CONTEXT, metadata: { pagePath: '/', projectPath: 'p' } },
          { id: AI_CONTEXT_ID_AGENT_MD, metadata: { oid: 'abc' } },
          { id: AI_CONTEXT_ID_CHAT_RULE, metadata: { oid: 'def' } },
        ],
      },
    ];

    const state = getContextInjectionState(messages, '');

    expect(state[AI_CONTEXT_ID_PAGE_CONTEXT]).toBeDefined();
    expect(state[AI_CONTEXT_ID_AGENT_MD]).toBeDefined();
    expect(state[AI_CONTEXT_ID_CHAT_RULE]).toBeDefined();
  });
});

describe('SystemContextManager', () => {
  describe('registerProvider', () => {
    it('collects items from all providers and handles errors', async () => {
      const manager = new SystemContextManager();
      const mockItem = { id: 'item1' };

      const goodProvider = { getItems: jest.fn().mockResolvedValue([mockItem]) };
      const badProvider = { getItems: jest.fn().mockRejectedValue(new Error()) };

      manager.registerProvider(goodProvider);
      manager.registerProvider(badProvider);

      const result = await manager.getSystemContextItems({});

      expect(result).toEqual([mockItem]);
    });
  });
});
