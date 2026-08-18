import Vue, { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import { GlButton, GlDisclosureDropdownItem } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import getConfiguredFlows from 'ee/ai/graphql/get_configured_flows.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import {
  mockCreateFlowResponse,
  mockDuoWorkflowStatusCheckEnabled,
  mockConfiguredFlowsResponse,
  mockEmptyConfiguredFlowsResponse,
} from '../../mocks';

jest.mock('~/alert');
jest.mock('ee/ai/events/panel');

Vue.use(VueApollo);

describe('DuoWorkflowAction component', () => {
  let wrapper;
  let mock;

  const projectId = 1;
  const duoWorkflowInvokePath = `/api/v4/ai/duo_workflows/workflows`;
  const currentRef = 'feature-branch';
  const sourceBranch = 'source-branch';

  const defaultProps = {
    projectPath: 'group/project',
    hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
    goal: 'Jenkinsfile',
    workflowDefinition: 'convert_to_gitlab_ci',
    agentPrivileges: [1, 2, 5],
  };

  let mockGetHealthCheckHandler;
  let mockGetConfiguredFlowsHandler;

  const createComponent = ({ props = {}, provide = {}, ...options } = {}) => {
    const handlers = [
      [getDuoWorkflowStatusCheck, mockGetHealthCheckHandler],
      [getConfiguredFlows, mockGetConfiguredFlowsHandler],
    ];
    wrapper = shallowMount(DuoWorkflowAction, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
      ...options,
    });

    return waitForPromises();
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: 'v4',
    };
    mock.onPost(duoWorkflowInvokePath).reply(() => {
      return [200, mockCreateFlowResponse];
    });
    mockGetHealthCheckHandler = jest.fn().mockResolvedValue(mockDuoWorkflowStatusCheckEnabled);
    mockGetConfiguredFlowsHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('rendering', () => {
    it('calls health checks query', async () => {
      await createComponent();

      expect(mockGetHealthCheckHandler).toHaveBeenCalled();
    });

    describe('when duoWorkflowStatusCheck, remoteFlowsEnabled, foundationalFlowsEnabled, and createDuoWorkflowForCiAllowed are all enabled', () => {
      beforeEach(async () => {
        await createComponent({
          slots: { default: 'My button' },
        });
      });

      it('renders button with correct props', () => {
        expect(findButton().props('category')).toBe('primary');
        expect(findButton().props('icon')).toBe('tanuki-ai');
        expect(findButton().props('size')).toBe('small');
        expect(findButton().props('variant')).toBe('default');
        expect(findButton().props('loading')).toBe(false);
        expect(findButton().attributes('title')).toBe(defaultProps.hoverMessage);
        expect(findButton().text()).toBe('My button');
      });

      it('renders with custom category prop', async () => {
        await createComponent({
          props: { category: 'tertiary' },
          slots: { default: 'My button' },
        });

        expect(findButton().props('category')).toBe('tertiary');
      });
    });

    describe('when duoWorkflowStatusCheck is null', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              duoWorkflowStatusCheck: null,
            },
          },
        });
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe.each`
      enabled  | remoteFlowsEnabled | foundationalFlowsEnabled | createDuoWorkflowForCiAllowed | expected
      ${false} | ${false}           | ${false}                 | ${false}                      | ${false}
      ${true}  | ${false}           | ${false}                 | ${false}                      | ${false}
      ${true}  | ${null}            | ${true}                  | ${true}                       | ${false}
      ${true}  | ${true}            | ${true}                  | ${false}                      | ${false}
      ${true}  | ${true}            | ${true}                  | ${null}                       | ${true}
      ${false} | ${true}            | ${true}                  | ${true}                       | ${false}
    `(
      'when enabled is $enabled, remoteFlowsEnabled is $remoteFlowsEnabled, foundationalFlowsEnabled is $foundationalFlowsEnabled and createDuoWorkflowForCiAllowed is $createDuoWorkflowForCiAllowed',
      ({
        enabled,
        remoteFlowsEnabled,
        foundationalFlowsEnabled,
        createDuoWorkflowForCiAllowed,
        expected,
      }) => {
        beforeEach(async () => {
          mockGetHealthCheckHandler = jest.fn().mockResolvedValue({
            data: {
              project: {
                id: 'gid://gitlab/Project/1',
                duoWorkflowStatusCheck: {
                  enabled,
                  remoteFlowsEnabled,
                  foundationalFlowsEnabled,
                  createDuoWorkflowForCiAllowed,
                },
              },
            },
          });
          await createComponent();
        });

        it(`${expected ? 'renders' : 'does not render'} the button`, () => {
          expect(findButton().exists()).toBe(expected);
        });
      },
    );

    describe('when projectPath is empty', () => {
      beforeEach(async () => {
        await createComponent({ props: { projectPath: '' } });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('does not call health checks query', () => {
        expect(mockGetHealthCheckHandler).not.toHaveBeenCalled();
      });
    });

    describe('when duoWorkflowStatusCheck is enabled with remoteFlowsEnabled but projectId is missing', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest.fn().mockResolvedValue({
          data: {
            project: {
              id: null,
              duoWorkflowStatusCheck: {
                enabled: true,
                remoteFlowsEnabled: true,
                foundationalFlowsEnabled: true,
              },
            },
          },
        });
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('loading state', () => {
    beforeEach(async () => {
      await createComponent();
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(() => new Promise(() => {}));

        findButton().vm.$emit('click');
        await nextTick();
      });

      it('shows loading state', () => {
        expect(findButton().props('loading')).toBe(true);
      });
    });

    describe('when the flow starts successfully', () => {
      beforeEach(async () => {
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('removes loading state when workflow starts successfully', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when the flow fails to start', () => {
      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(500);
        findButton().vm.$emit('click');

        await waitForPromises();
      });
      it('removes loading state when workflow fails to start', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });
  });

  describe('startWorkflow', () => {
    const expectedRequestData = {
      project_id: projectId,
      start_workflow: true,
      environment: 'web',
      goal: defaultProps.goal,
      workflow_definition: defaultProps.workflowDefinition,
      agent_privileges: defaultProps.agentPrivileges,
      additional_context: [],
      ai_catalog_item_consumer_id: 123,
    };

    beforeEach(async () => {
      await createComponent();
    });
    describe('when the goal fails to match the promptValidatorRegex', () => {
      const invalidGoal = 'InvalidPath';

      beforeEach(async () => {
        await createComponent({
          props: { goal: invalidGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ },
        });
        findButton().vm.$emit('click');
      });

      it('emits prompt-validation-error', () => {
        expect(wrapper.emitted('prompt-validation-error')).toEqual([[invalidGoal]]);
      });

      it('does not show loading state for validation errors', () => {
        expect(findButton().props('loading')).toBe(false);
      });

      it('does not make API call', () => {
        expect(mock.history.post).toHaveLength(0);
      });
    });

    describe('when the goal matches the promptVaidatorRegex', () => {
      const validGoal = 'Jenkinsfile';

      beforeEach(async () => {
        await createComponent({
          props: { goal: validGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ },
        });
        findButton().vm.$emit('click');
      });

      it('does not emit prompt-validation-error when goal matches regex', () => {
        expect(wrapper.emitted('prompt-validation-error')).toBeUndefined();
      });

      it('makes API call', () => {
        expect(mock.history.post).toHaveLength(1);
      });
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('makes API call with correct data', () => {
        const request = mock.history.post[0];
        expect(JSON.parse(request.data)).toEqual(expectedRequestData);
      });
    });

    describe('additionalContext handling', () => {
      describe('when additionalContext is provided', () => {
        const additionalContext = [
          {
            Category: 'agent_user_environment',
            Content: "{'merge_request_url': 'test.com'}",
            Metadata: '{}',
          },
          {
            Category: 'file_content',
            Content: 'pipeline content',
            Metadata: '{"type": "jenkins"}',
          },
        ];

        beforeEach(async () => {
          await createComponent({ props: { additionalContext } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes additional_context array in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: additionalContext,
          });
        });
      });

      describe('when additionalContext is an empty array', () => {
        const additionalContext = [];

        beforeEach(async () => {
          await createComponent({ props: { additionalContext } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes empty additional_context array in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: [],
          });
        });
      });

      describe('when additionalContext is not provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes empty array as additional_context in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: [],
          });
        });
      });
    });

    describe('source branch handling', () => {
      describe('when currentRef is provided', () => {
        beforeEach(async () => {
          await createComponent({ provide: { currentRef } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes currentRef as source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: currentRef,
          });
        });
      });

      describe('when sourceBranch prop is provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { sourceBranch } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes sourceBranch as source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: sourceBranch,
          });
        });
      });

      describe('when both currentRef and sourceBranch are provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { sourceBranch }, provide: { currentRef } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('prioritizes sourceBranch over currentRef', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: sourceBranch,
          });
        });
      });

      describe('when neither currentRef nor sourceBranch are provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('does not include source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual(expectedRequestData);
        });
      });
    });

    describe('work item type handling', () => {
      describe('when workItemIid is provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { workItemIid: '1' } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes workItemIid in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            issue_id: '1',
          });
        });
      });

      describe('when workItemIid is not provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('does not include work_item_id in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual(expectedRequestData);
        });
      });
    });

    describe('source handling', () => {
      describe('when source prop is provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { source: 'merge_request_code_conflict' } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes source in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source: 'merge_request_code_conflict',
          });
        });
      });

      describe('when source prop is not provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('does not include source in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual(expectedRequestData);
        });
      });
    });

    describe('merge request handling', () => {
      describe('when mergeRequestId is provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { mergeRequestId: 5 } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes merge_request_id in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            merge_request_id: 5,
          });
        });
      });

      describe('when mergeRequestId is not provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('does not include merge_request_id in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual(expectedRequestData);
        });
      });
    });

    describe('when request succeeds', () => {
      describe('side effects', () => {
        beforeEach(async () => {
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('emits agent-flow-started event', () => {
          expect(wrapper.emitted('agent-flow-started')).toEqual([[mockCreateFlowResponse]]);
        });

        it('removes loading state after success', () => {
          expect(findButton().props('loading')).toBe(false);
        });
      });

      describe('when the request succeeds', () => {
        beforeEach(async () => {
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('sets the open AI panel to the newly created session', () => {
          expect(eventHub.$emit).toHaveBeenCalledWith(SHOW_SESSION, mockCreateFlowResponse);
        });
      });
    });

    describe('when request succeeds but workload fails', () => {
      const mockFailedWorkloadResponse = {
        id: 563,
        project_id: 1,
        workload: {
          id: null,
          message: 'Branch already exists',
        },
      };

      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(200, mockFailedWorkloadResponse);
        await createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert with generic message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the flow.',
          captureError: true,
          error: expect.any(Error),
          renderMessageHTML: true,
        });
      });

      it('does not emit agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
      });

      it('removes loading state after error', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(500);
        await createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the flow.',
          captureError: true,
          error: expect.any(Error),
          renderMessageHTML: true,
        });
      });

      it('does not emits agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
      });

      it('removes loading state after error', () => {
        expect(findButton().props('loading')).toBe(false);
      });

      describe('when request fails with a specific error message', () => {
        const apiErrorMessage =
          'GitLab Duo Agent Platform onboarding is incomplete, composite identity must be enabled.';

        beforeEach(async () => {
          mock.onPost(duoWorkflowInvokePath).reply(403, { message: apiErrorMessage });
          await createComponent();
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('shows error alert with the API error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: apiErrorMessage,
            captureError: true,
            error: expect.any(Error),
            renderMessageHTML: true,
          });
        });

        it('does not emit agent-flow-started event', () => {
          expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
        });

        it('removes loading state after error', () => {
          expect(findButton().props('loading')).toBe(false);
        });
      });
    });
  });

  describe('Flow settings', () => {
    describe('when flow is configured in settings', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('renders button', () => {
        expect(findButton().exists()).toBe(true);
      });

      it('calls getConfiguredFlows query with correct variables', () => {
        expect(mockGetConfiguredFlowsHandler).toHaveBeenCalledWith({
          projectId: 'gid://gitlab/Project/1',
          foundationalFlowReference: 'convert_to_gitlab_ci',
        });
      });
    });

    describe('when flow is not configured in settings', () => {
      beforeEach(async () => {
        mockGetConfiguredFlowsHandler = jest
          .fn()
          .mockResolvedValue(mockEmptyConfiguredFlowsResponse);
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('calls getConfiguredFlows query', () => {
        expect(mockGetConfiguredFlowsHandler).toHaveBeenCalled();
      });
    });

    describe('when getConfiguredFlows query fails', () => {
      const errorMessage = 'Something went wrong.';

      beforeEach(async () => {
        mockGetConfiguredFlowsHandler = jest.fn().mockRejectedValue(new Error(errorMessage));
        await createComponent();
      });

      it('shows error alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: errorMessage,
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('when projectGid or workflowDefinition is missing', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest.fn().mockResolvedValue({
          data: {
            project: {
              id: null,
              duoWorkflowStatusCheck: {
                enabled: true,
                remoteFlowsEnabled: true,
                foundationalFlowsEnabled: true,
              },
            },
          },
        });
        await createComponent();
      });

      it('skips getConfiguredFlows query', () => {
        expect(mockGetConfiguredFlowsHandler).not.toHaveBeenCalled();
      });
    });
  });

  describe('renderAs prop', () => {
    describe('when renderAs is "button" (default)', () => {
      it('renders a GlButton and no GlDisclosureDropdownItem', async () => {
        await createComponent();

        expect(findButton().exists()).toBe(true);
        expect(findDropdownItem().exists()).toBe(false);
      });
    });

    describe('when renderAs is "dropdown-item"', () => {
      it('renders a GlDisclosureDropdownItem and no GlButton', async () => {
        await createComponent({ props: { renderAs: 'dropdown-item' } });

        expect(findDropdownItem().exists()).toBe(true);
        expect(findButton().exists()).toBe(false);
      });

      it('starts the workflow when the item is actioned', async () => {
        await createComponent({ props: { renderAs: 'dropdown-item' } });
        findDropdownItem().vm.$emit('action');
        await waitForPromises();

        expect(mock.history.post).toHaveLength(1);
      });
    });
  });

  describe('triggering and triggered events', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('emits triggering when the workflow starts', async () => {
      mock.onPost(duoWorkflowInvokePath).reply(() => new Promise(() => {}));

      findButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('triggering')).toHaveLength(1);
    });

    it('emits triggered when the workflow request succeeds', async () => {
      findButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('triggered')).toHaveLength(1);
    });

    it('emits triggered when the workflow request fails', async () => {
      mock.onPost(duoWorkflowInvokePath).reply(500);
      findButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('triggered')).toHaveLength(1);
    });
  });
});
