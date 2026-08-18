import { shallowMount } from '@vue/test-utils';
import { GlSkeletonLoader } from '@gitlab/ui';
import { DuoChatContextConversation as DuoChatConversation } from '@gitlab/duo-ui';
import AgentActivityLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_activity_logs.vue';
import AgentFlowEmptyState from 'ee/ai/duo_agents_platform/components/common/agent_flow_empty_state.vue';
import MessageTodoChecklist from 'ee/ai/duo_agents_platform/components/common/message_todo_checklist.vue';
import { mockItems } from '../../../components/common/mock';

describe('AgentActivityLogs', () => {
  let wrapper;

  const findChatConversation = () => wrapper.findComponent(DuoChatConversation);
  const findSkeletonLoader = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(AgentFlowEmptyState);

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AgentActivityLogs, {
      propsData: {
        isLoading: false,
        duoMessages: [],
        createdAt: '2022-03-11T04:30:00Z',
        updatedAt: '2022-03-11T04:35:00Z',
        status: 'FINISHED',
        user: {},
        ...props,
      },
    });
  };

  describe('when loading', () => {
    beforeEach(() => createWrapper({ isLoading: true }));

    it('renders skeleton loaders', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render the empty state or chat conversation', () => {
      expect(findEmptyState().exists()).toBe(false);
      expect(findChatConversation().exists()).toBe(false);
    });
  });

  describe('with no messages', () => {
    beforeEach(() => createWrapper({ duoMessages: [] }));

    it('renders the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not render the chat conversation or skeleton loaders', () => {
      expect(findChatConversation().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  describe('with messages', () => {
    beforeEach(() => {
      createWrapper({ duoMessages: mockItems });
    });

    it('renders DuoChatConversation', () => {
      expect(findChatConversation().exists()).toBe(true);
    });

    it('passes transformed messages to DuoChatConversation', () => {
      const messages = findChatConversation().props('messages');

      expect(messages).toHaveLength(mockItems.length);
      expect(messages[0]).toMatchObject({
        message_type: mockItems[0].messageType,
        role: expect.any(String),
      });
    });

    it('disables feedback, code insertion, and delimiter', () => {
      expect(findChatConversation().props('showDelimiter')).toBe(false);
      expect(findChatConversation().props('withFeedback')).toBe(false);
      expect(findChatConversation().props('enableCodeInsertion')).toBe(false);
    });

    it('passes messageRenderers with the approval request renderer', () => {
      const renderers = findChatConversation().props('messageRenderers');

      expect(renderers).toHaveLength(2);
      expect(renderers[0].matchMessage({ message_type: 'request' })).toBe(true);
      expect(renderers[0].matchMessage({ message_type: 'agent' })).toBe(false);
    });

    it('passes messageRenderers with the todo_write renderer', () => {
      const renderers = findChatConversation().props('messageRenderers');
      const todoRenderer = renderers.find((r) => r.component === MessageTodoChecklist);

      expect(todoRenderer.matchMessage({ tool_info: { name: 'todo_write' } })).toBe(true);
      expect(todoRenderer.matchMessage({ tool_info: JSON.stringify({ name: 'todo_write' }) })).toBe(
        true,
      );
      expect(todoRenderer.matchMessage({ tool_info: { name: 'read_file' } })).toBe(false);
      expect(todoRenderer.matchMessage({ tool_info: null })).toBe(false);
      expect(todoRenderer.matchMessage({})).toBe(false);
    });
  });

  describe('todo_write spinner freezing', () => {
    const todoMessage = (todos) => ({
      messageType: 'tool',
      toolInfo: JSON.stringify({ name: 'todo_write', args: { todos } }),
    });
    const todoMessages = [
      todoMessage([{ description: 'first plan', status: 'in_progress' }]),
      todoMessage([{ description: 'second plan', status: 'in_progress' }]),
    ];
    const findTodoMessages = () =>
      findChatConversation()
        .props('messages')
        .filter((message) => message.tool_info?.name === 'todo_write');

    describe('when the session is still running', () => {
      beforeEach(() => {
        createWrapper({ duoMessages: todoMessages, status: 'RUNNING' });
      });

      it('marks earlier todo lists as finished and leaves the latest one active', () => {
        const todos = findTodoMessages();
        expect(todos[0].todoFinished).toBe(true);
        expect(todos[1].todoFinished).toBe(false);
      });
    });

    describe('when the session has reached a terminal state', () => {
      beforeEach(() => {
        createWrapper({ duoMessages: todoMessages, status: 'FINISHED' });
      });

      it('freezes all todo lists', () => {
        expect(findTodoMessages().every((message) => message.todoFinished)).toBe(true);
      });
    });
  });

  describe('when session has failed', () => {
    beforeEach(() => {
      createWrapper({ duoMessages: mockItems, status: 'FAILED' });
    });

    it('does not append a session failed error bubble to chatMessages', () => {
      const messages = findChatConversation().props('messages');
      const lastMessage = messages[messages.length - 1];

      expect(lastMessage.requestId).not.toBe('session-failed');
    });
  });
});
