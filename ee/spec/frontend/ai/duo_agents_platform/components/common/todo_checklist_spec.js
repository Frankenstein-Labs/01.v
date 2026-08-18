import { GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TodoChecklist from 'ee/ai/duo_agents_platform/components/common/todo_checklist.vue';

describe('TodoChecklist', () => {
  let wrapper;

  const findContainer = () => wrapper.findByTestId('todo-checklist-container');
  const findAllItems = () => wrapper.findAll('li');
  const findAllIcons = () => wrapper.findAllComponents(GlIcon);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createWrapper = (toolInfo = {}, props = {}) => {
    wrapper = shallowMountExtended(TodoChecklist, {
      propsData: { toolInfo, ...props },
    });
  };

  const mockTodos = [
    { status: 'completed', description: 'Set up repository' },
    { status: 'in_progress', description: 'Write tests' },
    { status: 'pending', description: 'Deploy to staging' },
    { status: 'cancelled', description: 'Old task' },
    { status: 'unknown_status', description: 'Mystery task' },
  ];

  describe('when todos are present', () => {
    beforeEach(() => {
      createWrapper({ args: { todos: mockTodos } });
    });

    it('renders correct number of list items', () => {
      expect(findAllItems()).toHaveLength(mockTodos.length);
    });

    it('renders check icon for completed status', () => {
      expect(findAllIcons().at(0).props('name')).toBe('check');
    });

    it('renders loading icon for in_progress status', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('renders dash-circle icon for pending status', () => {
      expect(findAllIcons().at(1).props('name')).toBe('dash-circle');
    });

    it('renders close icon for cancelled status', () => {
      expect(findAllIcons().at(2).props('name')).toBe('close');
    });

    it('renders dash-circle icon for unknown status string', () => {
      expect(findAllIcons().at(3).props('name')).toBe('dash-circle');
    });

    it('renders description text for each todo', () => {
      mockTodos.forEach((todo, index) => {
        expect(findAllItems().at(index).text()).toContain(todo.description);
      });
    });
  });

  describe('bordered prop', () => {
    describe('when bordered is true (default)', () => {
      beforeEach(() => {
        createWrapper({ args: { todos: mockTodos } });
      });

      it('applies border classes', () => {
        expect(findContainer().classes()).toContain('gl-border');
      });
    });

    describe('when bordered is false', () => {
      beforeEach(() => {
        createWrapper({ args: { todos: mockTodos } }, { bordered: false });
      });

      it('does not apply border classes', () => {
        expect(findContainer().classes()).not.toContain('gl-border');
      });
    });
  });

  describe('flowFinished prop', () => {
    const inProgressTodos = [{ status: 'in_progress', description: 'Write tests' }];

    describe('when flowFinished is false (default)', () => {
      beforeEach(() => {
        createWrapper({ args: { todos: inProgressTodos } });
      });

      it('renders the loading icon for an in_progress todo', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });
    });

    describe('when flowFinished is true', () => {
      beforeEach(() => {
        createWrapper({ args: { todos: inProgressTodos } }, { flowFinished: true });
      });

      it('does not render the loading icon for an in_progress todo', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('renders a static icon instead', () => {
        expect(findAllIcons().at(0).exists()).toBe(true);
      });
    });
  });

  describe('when todos array is empty', () => {
    it('renders nothing', () => {
      createWrapper({ args: { todos: [] } });
      expect(findContainer().exists()).toBe(false);
    });
  });

  describe('when args is missing', () => {
    it('handles missing args gracefully (renders nothing)', () => {
      createWrapper({});
      expect(findContainer().exists()).toBe(false);
    });
  });

  describe('when args.todos is missing', () => {
    it('handles missing args.todos gracefully (renders nothing)', () => {
      createWrapper({ args: {} });
      expect(findContainer().exists()).toBe(false);
    });
  });
});
