import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import TestCaseShowRoot from 'ee/test_case_show/components/test_case_show_root.vue';
import IssuableShow from '~/vue_shared/issuable/show/components/issuable_show_root.vue';
import markTestCaseTodoDone from 'ee/test_case_show/queries/mark_test_case_todo_done.mutation.graphql';
import moveTestCase from 'ee/test_case_show/queries/move_test_case.mutation.graphql';
import updateTestCase from 'ee/test_case_show/queries/update_test_case.mutation.graphql';
import projectTestCase from 'ee/test_case_show/queries/project_test_case.query.graphql';
import projectTestCaseTaskList from 'ee/test_case_show/queries/test_case_tasklist.query.graphql';
import { mockCurrentUserTodo } from 'jest/vue_shared/issuable/list/mock_data';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';

import Api from '~/api';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';

import {
  markTestCaseTodoDoneResponse,
  updateTestCaseResponse,
  moveTestCaseResponse,
  mockProvide,
  mockTestCase,
  mockTestCaseResponse,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility');

Vue.use(VueApollo);

const markTestCaseTodoDoneSpy = jest.fn().mockResolvedValue(markTestCaseTodoDoneResponse);
const moveTestCaseSpy = jest.fn().mockResolvedValue(moveTestCaseResponse);
const updateTestCaseSpy = jest.fn().mockResolvedValue(updateTestCaseResponse);
const projectTestCaseSpy = jest.fn().mockResolvedValue(mockTestCaseResponse());
const projectTestCaseTaskListSpy = jest.fn().mockResolvedValue({});

const defaultRequestHandlers = {
  markTestCaseTodoDone: markTestCaseTodoDoneSpy,
  moveTestCase: moveTestCaseSpy,
  updateTestCase: updateTestCaseSpy,
  projectTestCase: projectTestCaseSpy,
  projectTestCaseTaskList: projectTestCaseTaskListSpy,
};

describe('TestCaseGraphQL Mixin', () => {
  let wrapper;
  let requestHandlers;

  const createComponent = ({ testCase, testCaseQueryLoading = false, handlers = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = shallowMount(TestCaseShowRoot, {
      provide: {
        ...mockProvide,
      },
      stubs: {
        IssuableShow: stubComponent(IssuableShow),
      },
      data() {
        return {
          testCaseLoading: testCaseQueryLoading,
          testCase: testCaseQueryLoading
            ? {}
            : {
                ...mockTestCase,
                ...testCase,
              },
        };
      },
      apolloProvider: createMockApollo([
        [projectTestCase, requestHandlers.projectTestCase],
        [projectTestCaseTaskList, requestHandlers.projectTestCaseTaskList],
        [markTestCaseTodoDone, requestHandlers.markTestCaseTodoDone],
        [moveTestCase, requestHandlers.moveTestCase],
        [updateTestCase, requestHandlers.updateTestCase],
      ]),
    });
  };

  describe('updateTestCase', () => {
    it('calls mutation to update the test case correctly', () => {
      createComponent();
      wrapper.vm.updateTestCase({
        variables: { title: 'Foo' },
        errorMessage: 'Something went wrong',
      });

      expect(updateTestCaseSpy).toHaveBeenCalledWith({
        input: {
          projectPath: mockProvide.projectFullPath,
          iid: mockProvide.testCaseId,
          title: 'Foo',
        },
      });
    });

    it('creates an alert when updating a test case fails', async () => {
      const errorUpdateTestCaseSpy = jest
        .fn()
        .mockRejectedValue({ data: { updateIssue: { errors: ['Foo'], issue: {} } } });
      createComponent({ handlers: { updateTestCase: errorUpdateTestCaseSpy } });
      const errorMessage = 'Something went wrong';
      wrapper.vm.updateTestCase({ variables: { title: 'Foo' }, errorMessage });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        captureError: true,
        error: expect.any(Object),
      });
    });
  });

  describe('addTestCaseAsTodo', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets `testCaseTodoUpdateInProgress` to true', () => {
      jest.spyOn(Api, 'addProjectIssueAsTodo').mockResolvedValue({});
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
      wrapper.vm.addTestCaseAsTodo();

      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(true);
    });

    it('calls `Api.addProjectIssueAsTodo` method with params `projectFullPath` and `testCaseId`', () => {
      jest.spyOn(Api, 'addProjectIssueAsTodo').mockResolvedValue({});
      wrapper.vm.addTestCaseAsTodo();

      expect(Api.addProjectIssueAsTodo).toHaveBeenCalledWith(
        mockProvide.projectFullPath,
        mockProvide.testCaseId,
      );
    });

    it('refetches project test case data when a new test case is added', async () => {
      jest.spyOn(Api, 'addProjectIssueAsTodo').mockResolvedValue({});
      expect(projectTestCaseSpy).toHaveBeenCalledTimes(1);
      wrapper.vm.addTestCaseAsTodo();
      await waitForPromises();

      expect(projectTestCaseSpy).toHaveBeenCalledTimes(2);
      expect(projectTestCaseSpy).toHaveBeenLastCalledWith({
        projectPath: mockProvide.projectFullPath,
        testCaseId: mockProvide.testCaseId,
      });
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
    });

    it('creates an alert when adding a new test case fails', async () => {
      jest.spyOn(Api, 'addProjectIssueAsTodo').mockRejectedValue({});
      wrapper.vm.addTestCaseAsTodo();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong while adding test case to a to-do item.',
        captureError: true,
        error: expect.any(Object),
      });
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
    });
  });

  describe('markTestCaseTodoDone', () => {
    it('sets `testCaseTodoUpdateInProgress` to true', () => {
      createComponent();
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
      wrapper.vm.markTestCaseTodoDone();

      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(true);
    });

    it('calls mutation to mark test case todo as done correctly', () => {
      createComponent();
      wrapper.vm.markTestCaseTodoDone();

      expect(markTestCaseTodoDoneSpy).toHaveBeenCalledWith({
        todoMarkDoneInput: { id: mockCurrentUserTodo.id },
      });
    });

    it('refetches project test cases when a test case is updated', async () => {
      createComponent();
      expect(projectTestCaseSpy).toHaveBeenCalledTimes(1);
      wrapper.vm.markTestCaseTodoDone();
      await waitForPromises();

      expect(projectTestCaseSpy).toHaveBeenCalledTimes(2);
      expect(projectTestCaseSpy).toHaveBeenLastCalledWith({
        projectPath: mockProvide.projectFullPath,
        testCaseId: mockProvide.testCaseId,
      });
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
    });

    it('creates an alert when updating a test case fails', async () => {
      const errorMarkTestCaseTodoDoneSpy = jest.fn().mockRejectedValue({});
      createComponent({ handlers: { markTestCaseTodoDone: errorMarkTestCaseTodoDoneSpy } });
      wrapper.vm.markTestCaseTodoDone();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong while marking test case to-do item as done.',
        captureError: true,
        error: expect.any(Object),
      });
      expect(wrapper.vm.testCaseTodoUpdateInProgress).toBe(false);
    });
  });

  describe('moveTestCase', () => {
    const mockTargetProject = {
      full_path: 'gitlab-org/gitlab-shell',
    };

    it('sets `testCaseMoveInProgress` to true', () => {
      createComponent();
      expect(wrapper.vm.testCaseMoveInProgress).toBe(false);
      wrapper.vm.moveTestCase(mockTargetProject);

      expect(wrapper.vm.testCaseMoveInProgress).toBe(true);
    });

    it('calls mutation to move test case correctly', async () => {
      createComponent();
      expect(moveTestCaseSpy).not.toHaveBeenCalled();
      wrapper.vm.moveTestCase(mockTargetProject);
      await waitForPromises();

      expect(moveTestCaseSpy).toHaveBeenCalledWith({
        moveTestCaseInput: {
          projectPath: mockProvide.projectFullPath,
          iid: mockProvide.testCaseId,
          targetProjectPath: mockTargetProject.full_path,
        },
      });
    });

    it('navigates the user to a new page when a test case is moved successfully', async () => {
      createComponent();
      expect(visitUrl).not.toHaveBeenCalled();
      wrapper.vm.moveTestCase(mockTargetProject);
      await waitForPromises();

      expect(visitUrl).toHaveBeenCalledWith(moveTestCaseResponse.data.issueMove.issue.webUrl);
    });

    it('creates an alert when moving a test case fails', async () => {
      const errorMoveTestCaseSpy = jest.fn().mockRejectedValue({});
      createComponent({ handlers: { moveTestCase: errorMoveTestCaseSpy } });
      wrapper.vm.moveTestCase(mockTargetProject);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong while moving test case.',
        captureError: true,
        error: expect.any(Object),
      });
      expect(wrapper.vm.testCaseMoveInProgress).toBe(false);
    });
  });
});
