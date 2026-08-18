import { GlFormGroup, GlFormTextarea } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import AgentFlowUserApproval from 'ee/ai/duo_agents_platform/components/common/agent_flow_user_approval.vue';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';
import { resumeWorkflow, cancelWorkflow } from 'ee/rest_api';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { mockGetAgentFlowResponse } from '../../../mocks';

jest.mock('ee/rest_api', () => ({
  resumeWorkflow: jest.fn(),
  cancelWorkflow: jest.fn(),
}));
jest.mock('~/alert', () => ({
  createAlert: jest.fn(),
}));

Vue.use(VueApollo);

describe('AgentFlowUserApproval', () => {
  let wrapper;
  let getAgentFlowHandler;
  const mockWorkflowId = '123';

  const createWrapper = () => {
    getAgentFlowHandler = jest.fn().mockResolvedValue(mockGetAgentFlowResponse);

    wrapper = shallowMountExtended(AgentFlowUserApproval, {
      apolloProvider: createMockApollo([[getAgentFlow, getAgentFlowHandler]]),
      mocks: {
        $route: { params: { id: mockWorkflowId } },
      },
    });
  };

  beforeEach(() => {
    jest.clearAllMocks();
    resumeWorkflow.mockResolvedValue({});
    cancelWorkflow.mockResolvedValue({});
    createWrapper();
  });

  const findEditForm = () => wrapper.findComponent(GlFormGroup);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findModifyButton = () => wrapper.findComponentByTestId('flow-user-approval-modify-button');
  const findRejectButton = () => wrapper.findComponentByTestId('flow-user-approval-reject-button');
  const findApproveButton = () =>
    wrapper.findComponentByTestId('flow-user-approval-approve-button');
  const findCancelButton = () => wrapper.findComponentByTestId('flow-user-approval-cancel-button');
  const findSubmitButton = () => wrapper.findComponentByTestId('flow-user-approval-submit-button');

  const enterEditMode = async () => {
    findModifyButton().vm.$emit('click');
    await nextTick();
  };

  const exitEditMode = async () => {
    findCancelButton().vm.$emit('click');
    await nextTick();
  };

  const fillAndSubmitForm = async (text) => {
    findTextarea().vm.$emit('input', text);
    await nextTick();
    findSubmitButton().vm.$emit('click');
    await waitForPromises();
  };

  const assertApprovalMode = () => {
    expect(findModifyButton().exists()).toBe(true);
    expect(findRejectButton().exists()).toBe(true);
    expect(findApproveButton().exists()).toBe(true);
    expect(findEditForm().exists()).toBe(false);
  };

  const assertEditMode = () => {
    expect(findEditForm().exists()).toBe(true);
    expect(findCancelButton().exists()).toBe(true);
    expect(findSubmitButton().exists()).toBe(true);
    expect(findModifyButton().exists()).toBe(false);
    expect(findRejectButton().exists()).toBe(false);
    expect(findApproveButton().exists()).toBe(false);
  };

  const assertHidden = () => {
    expect(findModifyButton().exists()).toBe(false);
    expect(findRejectButton().exists()).toBe(false);
    expect(findApproveButton().exists()).toBe(false);
    expect(findEditForm().exists()).toBe(false);
  };

  describe('initial state', () => {
    it('shows approval buttons and hides edit form', () => {
      assertApprovalMode();
    });

    it('does not fetch the agent flow before an approval is submitted', () => {
      expect(getAgentFlowHandler).not.toHaveBeenCalled();
    });
  });

  describe('mode transitions', () => {
    it('enters edit mode when modify button is clicked', async () => {
      await enterEditMode();
      assertEditMode();
    });

    it('returns to approval mode when cancel is clicked', async () => {
      await enterEditMode();
      await exitEditMode();
      assertApprovalMode();
    });

    it('returns to approval mode after submitting a modification', async () => {
      await enterEditMode();
      await fillAndSubmitForm('Change the plan');
      assertApprovalMode();
    });
  });

  describe('submit button', () => {
    it('is disabled when no modification text has been entered', async () => {
      await enterEditMode();
      findTextarea().vm.$emit('');
      await nextTick();

      expect(findSubmitButton().attributes('disabled')).toBeDefined();
    });

    it('makes API call with user input when clicked', async () => {
      await enterEditMode();
      await fillAndSubmitForm('Change the plan');

      expect(resumeWorkflow).toHaveBeenCalledWith(mockWorkflowId, {
        humanApproval: false,
        humanMessage: 'Change the plan',
      });
    });

    it('refetches the agent flow for the workflow in the route', async () => {
      await enterEditMode();
      await fillAndSubmitForm('Change the plan');

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, mockWorkflowId),
      });
    });

    it('disables button during submission and returns to approval mode on success', async () => {
      let resolvePost;
      resumeWorkflow.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolvePost = resolve;
          }),
      );

      await enterEditMode();
      findTextarea().vm.$emit('input', 'Change the plan');
      await nextTick();
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findSubmitButton().attributes('disabled')).toBeDefined();

      resolvePost({});
      await waitForPromises();

      assertApprovalMode();
    });
  });

  describe('approve button', () => {
    it('makes API call with correct payload when clicked', async () => {
      findApproveButton().vm.$emit('click');
      await waitForPromises();

      expect(resumeWorkflow).toHaveBeenCalledWith(mockWorkflowId, {
        humanApproval: true,
      });
    });

    it('refetches the agent flow for the workflow in the route', async () => {
      findApproveButton().vm.$emit('click');
      await waitForPromises();

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, mockWorkflowId),
      });
    });

    it('disables button during submission and hides component on success', async () => {
      let resolvePost;
      resumeWorkflow.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolvePost = resolve;
          }),
      );

      findApproveButton().vm.$emit('click');
      await nextTick();

      expect(findApproveButton().attributes('disabled')).toBeDefined();

      resolvePost({});
      await waitForPromises();

      assertHidden();
    });
  });

  describe('reject button', () => {
    it('makes API call with correct payload when clicked', async () => {
      findRejectButton().vm.$emit('click');
      await waitForPromises();

      expect(cancelWorkflow).toHaveBeenCalledWith(mockWorkflowId);
    });

    it('refetches the agent flow for the workflow in the route', async () => {
      findRejectButton().vm.$emit('click');
      await waitForPromises();

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, mockWorkflowId),
      });
    });

    it('disables button during submission and hides component on success', async () => {
      let resolvePost;
      cancelWorkflow.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolvePost = resolve;
          }),
      );

      findRejectButton().vm.$emit('click');
      await nextTick();

      expect(findRejectButton().attributes('disabled')).toBeDefined();

      resolvePost({});
      await waitForPromises();

      assertHidden();
    });
  });
});
