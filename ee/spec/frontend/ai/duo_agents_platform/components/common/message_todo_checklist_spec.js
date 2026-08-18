import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MessageTodoChecklist from 'ee/ai/duo_agents_platform/components/common/message_todo_checklist.vue';
import TodoChecklist from 'ee/ai/duo_agents_platform/components/common/todo_checklist.vue';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';

describe('MessageTodoChecklist', () => {
  let wrapper;

  const mockTodos = [
    { description: 'Read duo_base_tool.py', status: 'completed' },
    { description: 'Create branch from main', status: 'completed' },
    { description: 'Extract pagination logic', status: 'in_progress' },
    { description: 'Add pagination tests', status: 'pending' },
  ];

  const parsedToolInfo = {
    name: 'todo_write',
    args: { todos: mockTodos },
  };

  const createComponent = ({ message = {} } = {}) => {
    wrapper = shallowMountExtended(MessageTodoChecklist, {
      propsData: { message },
    });
  };

  const findTodoChecklist = () => wrapper.findComponent(TodoChecklist);

  describe('when message has toolInfo as a parsed object', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: parsedToolInfo } });
    });

    it('renders TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(true);
    });

    it('passes toolInfo to TodoChecklist', () => {
      expect(findTodoChecklist().props('toolInfo')).toEqual(parsedToolInfo);
    });
  });

  describe('when message has toolInfo as a JSON string', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: JSON.stringify(parsedToolInfo) } });
    });

    it('renders TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(true);
    });

    it('passes the parsed toolInfo object to TodoChecklist', () => {
      expect(findTodoChecklist().props('toolInfo')).toEqual(parsedToolInfo);
    });
  });

  describe('when message is normalized via WorkflowUtils (real runtime shape)', () => {
    beforeEach(() => {
      const [normalized] = WorkflowUtils.normalizeDuoMessages([
        { messageType: 'tool', toolInfo: JSON.stringify(parsedToolInfo) },
      ]);
      createComponent({ message: normalized });
    });

    it('renders TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(true);
    });

    it('passes the parsed toolInfo object to TodoChecklist', () => {
      expect(findTodoChecklist().props('toolInfo')).toEqual(parsedToolInfo);
    });
  });

  describe('when the message is marked todoFinished', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: parsedToolInfo, todoFinished: true } });
    });

    it('passes flowFinished as true to TodoChecklist', () => {
      expect(findTodoChecklist().props('flowFinished')).toBe(true);
    });
  });

  describe('when the message is not marked todoFinished', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: parsedToolInfo } });
    });

    it('passes flowFinished as false to TodoChecklist', () => {
      expect(findTodoChecklist().props('flowFinished')).toBe(false);
    });
  });

  describe('when message has toolInfo with no todos', () => {
    beforeEach(() => {
      createComponent({
        message: { tool_info: { name: 'todo_write', args: { todos: [] } } },
      });
    });

    it('renders TodoChecklist (TodoChecklist itself handles empty todos)', () => {
      expect(findTodoChecklist().exists()).toBe(true);
    });
  });

  describe('when message has no toolInfo', () => {
    beforeEach(() => {
      createComponent({ message: {} });
    });

    it('does not render TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(false);
    });
  });

  describe('when message has null toolInfo', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: null } });
    });

    it('does not render TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(false);
    });
  });

  describe('when message has invalid JSON string as toolInfo', () => {
    beforeEach(() => {
      createComponent({ message: { tool_info: 'not-valid-json{' } });
    });

    it('does not render TodoChecklist', () => {
      expect(findTodoChecklist().exists()).toBe(false);
    });
  });
});
