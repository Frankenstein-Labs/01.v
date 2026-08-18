import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { InputRequestedMessage } from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import getWorkflowPermissions from 'ee/ai/duo_agents_platform/graphql/queries/get_workflow_permissions.query.graphql';
import MessageApprovalRequest from 'ee/ai/duo_agents_platform/components/common/message_approval_request.vue';
import AgentFlowUserApproval from 'ee/ai/duo_agents_platform/components/common/agent_flow_user_approval.vue';
import { buildWorkflowPermissionsResponse } from './mock';

Vue.use(VueApollo);

describe('MessageApprovalRequest', () => {
  let wrapper;

  const workflowId = '1';
  const graphqlWorkflowId = convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, workflowId);

  const defaultMessage = {
    id: '1',
    content: 'Approval needed',
    isLastMessage: true,
  };

  const createComponent = ({
    message = {},
    permissions = {},
    route = { params: { id: workflowId } },
  } = {}) => {
    const apolloProvider = createMockApollo();
    apolloProvider.clients.defaultClient.cache.writeQuery({
      query: getWorkflowPermissions,
      variables: { workflowId: graphqlWorkflowId },
      data: buildWorkflowPermissionsResponse({ id: graphqlWorkflowId, ...permissions }),
    });

    wrapper = shallowMountExtended(MessageApprovalRequest, {
      apolloProvider,
      propsData: {
        message: { ...defaultMessage, ...message },
      },
      mocks: {
        $route: route,
      },
    });
  };

  const findInputRequestedMessage = () => wrapper.findComponent(InputRequestedMessage);
  const findAgentFlowUserApproval = () => wrapper.findComponent(AgentFlowUserApproval);

  describe('InputRequestedMessage', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders InputRequestedMessage with the message prop', () => {
      expect(findInputRequestedMessage().props('message')).toEqual(defaultMessage);
    });

    it('passes listeners to InputRequestedMessage', () => {
      const listener = jest.fn();
      const apolloProvider = createMockApollo();
      wrapper = shallowMountExtended(MessageApprovalRequest, {
        apolloProvider,
        propsData: { message: defaultMessage },
        mocks: { $route: { params: { id: workflowId } } },
        listeners: { 'custom-event': listener },
      });

      findInputRequestedMessage().vm.$emit('custom-event');

      expect(listener).toHaveBeenCalled();
    });
  });

  describe('AgentFlowUserApproval', () => {
    describe('when canResumeWorkflow, canUpdateWorkflow, and isLastMessage are all true', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(true);
      });
    });

    describe('when canResumeWorkflow is false', () => {
      beforeEach(async () => {
        createComponent({ permissions: { resumeDuoWorkflow: false } });
        await waitForPromises();
      });

      it('does not render the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(false);
      });
    });

    describe('when canUpdateWorkflow is false', () => {
      beforeEach(async () => {
        createComponent({ permissions: { updateDuoWorkflow: false } });
        await waitForPromises();
      });

      it('does not render the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(false);
      });
    });

    describe('when isLastMessage is false', () => {
      beforeEach(async () => {
        createComponent({ message: { isLastMessage: false } });
        await waitForPromises();
      });

      it('does not render the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(false);
      });
    });

    describe('when all conditions are false', () => {
      beforeEach(async () => {
        createComponent({
          message: { isLastMessage: false },
          permissions: { resumeDuoWorkflow: false, updateDuoWorkflow: false },
        });
        await waitForPromises();
      });

      it('does not render the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(false);
      });
    });

    describe('when the route has no workflow id', () => {
      beforeEach(async () => {
        createComponent({ route: { params: {} } });
        await waitForPromises();
      });

      it('skips the query and does not render the approval component', () => {
        expect(findAgentFlowUserApproval().exists()).toBe(false);
      });
    });
  });
});
