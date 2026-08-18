import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import TestCaseSidebarTodo from 'ee/test_case_show/components/test_case_sidebar_todo.vue';
import { mockCurrentUserTodo } from 'jest/vue_shared/issuable/list/mock_data';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import projectTestCase from 'ee/test_case_show/queries/project_test_case.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { mockProvide, mockTaskCompletionResponse } from '../mock_data';

Vue.use(VueApollo);

describe('TestCaseSidebarTodo', () => {
  let wrapper;

  const createComponent = ({
    provide = {},
    sidebarExpanded = true,
    todo = mockCurrentUserTodo,
  } = {}) => {
    const apolloProvider = createMockApollo([[projectTestCase, mockTaskCompletionResponse]]);

    wrapper = shallowMountExtended(TestCaseSidebarTodo, {
      provide: {
        ...mockProvide,
        ...provide,
      },
      apolloProvider,
      propsData: {
        sidebarExpanded,
        todo,
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findCollapsedTodoButton = () => wrapper.findByTestId('collapsed-button');
  const findExpandedTodoButton = () => wrapper.findByTestId('expanded-button');
  const findExpandedTodoEl = () => wrapper.findByTestId('todo');

  beforeEach(() => {
    setHTMLFixture('<aside class="right-sidebar"></aside>');
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('To Do section', () => {
    it('does not render when the test case can not be edited', () => {
      createComponent({
        provide: {
          canEditTestCase: false,
        },
      });

      expect(findExpandedTodoEl().exists()).toBe(false);
      expect(findCollapsedTodoButton().exists()).toBe(false);
    });

    describe('when expanded', () => {
      it('sidebarExpanded set to `true` renders expanded todo button', () => {
        createComponent({
          sidebarExpanded: true,
        });

        expect(findCollapsedTodoButton().exists()).toBe(false);
        expect(findExpandedTodoButton().exists()).toBe(true);
      });

      it('renders expanded todo button', () => {
        createComponent();

        const todoEl = findExpandedTodoEl();
        expect(todoEl.findComponent(GlButton).text()).toBe('Add a to-do item');
      });

      it('display loading icon', () => {
        createComponent({
          sidebarExpanded: true,
        });

        expect(findExpandedTodoButton().findComponent(GlLoadingIcon).exists()).toBe(true);
      });
    });

    describe('when collapsed', () => {
      it('sidebarExpanded set to `false` renders collapsed todo button', () => {
        createComponent({
          sidebarExpanded: false,
        });

        expect(findCollapsedTodoButton().exists()).toBe(true);
        expect(findExpandedTodoButton().exists()).toBe(false);
      });

      it('renders collapsed todo button', async () => {
        createComponent({
          sidebarExpanded: false,
        });
        await waitForPromises();

        const todoButton = findCollapsedTodoButton();

        expect(todoButton.attributes('title')).toBe('Add a to-do item');
      });

      it('display loading icon', () => {
        createComponent({
          sidebarExpanded: false,
        });

        expect(findCollapsedTodoButton().findComponent(GlLoadingIcon).exists()).toBe(true);
      });
    });
  });
});
