import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAnimatedLoaderIcon, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import TodoChecklist from 'ee/ai/duo_agents_platform/components/common/todo_checklist.vue';
import MessageToolStartFlow from 'ee/ai/duo_agentic_chat/components/messages/message_tool_start_flow.vue';
import getWorkflowLatestCheckpointQuery from 'ee/ai/graphql/get_workflow_latest_checkpoint.query.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';
import { EventsTracker } from 'ee/ai/duo_agentic_chat/observability/events_tracker';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import {
  MOCK_START_FLOW_TOOL_MESSAGE,
  MOCK_LATEST_CHECKPOINT_WITH_TODO,
  MOCK_LATEST_CHECKPOINT,
  MOCK_LATEST_CHECKPOINT_FINISHED,
  MOCK_LATEST_CHECKPOINT_EMPTY,
  MOCK_LATEST_CHECKPOINT_FINISHED_WITH_TODO,
} from '../mock_data';

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');
jest.mock('ee/ai/duo_agentic_chat/observability/events_tracker');

Vue.use(VueApollo);

describe('MessageToolStartFlow', () => {
  let wrapper;
  let flowPlanHandler;

  beforeEach(() => {
    flowPlanHandler = jest.fn().mockResolvedValue(MOCK_LATEST_CHECKPOINT);
  });

  const createComponent = (props = {}) => {
    const apolloProvider = createMockApollo();
    apolloProvider.defaultClient.setRequestHandler(
      getWorkflowLatestCheckpointQuery,
      flowPlanHandler,
    );

    wrapper = shallowMountExtended(MessageToolStartFlow, {
      propsData: { message: MOCK_START_FLOW_TOOL_MESSAGE, ...props },
      apolloProvider,
    });
  };

  const createMessageWithToolResponse = (content) => ({
    ...MOCK_START_FLOW_TOOL_MESSAGE,
    tool_info: {
      ...MOCK_START_FLOW_TOOL_MESSAGE.tool_info,
      tool_response: {
        ...MOCK_START_FLOW_TOOL_MESSAGE.tool_info.tool_response,
        content,
      },
    },
  });

  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);
  const findButton = () => wrapper.findByTestId('start-flow-message');
  const findLoadingIndicator = () => wrapper.findByTestId('start-flow-loading');
  const findTodoChecklist = () => wrapper.findComponent(TodoChecklist);
  const findLatestActivity = () => wrapper.findByTestId('latest-activity');
  const findLatestActivityDetail = () => wrapper.findByTestId('latest-activity-detail');
  const findLatestActivityToolName = () => wrapper.findByTestId('latest-activity-tool-name');
  const findAnimatedLoader = () => wrapper.findComponent(GlAnimatedLoaderIcon);

  describe('loading state', () => {
    it('shows a loading indicator while the query is in flight', () => {
      createComponent();

      expect(findLoadingIndicator().exists()).toBe(true);
      expect(findLoadingIndicator().findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findButton().exists()).toBe(false);
    });

    it('applies pill classes to the loading indicator', () => {
      createComponent();

      expect(findLoadingIndicator().classes()).toContain('gl-inline-flex');
    });

    it('hides the loading indicator once workflowStatus resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIndicator().exists()).toBe(false);
      expect(findButton().exists()).toBe(true);
    });

    it('does not show a loading indicator when workflowId is absent', () => {
      createComponent({
        message: createMessageWithToolResponse(
          JSON.stringify({ status: 'started', flow_name: 'fix_pipeline/v1' }),
        ),
      });

      expect(findLoadingIndicator().exists()).toBe(false);
      expect(findButton().exists()).toBe(true);
    });
  });

  describe('flow name', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('displays the flow name from tool_response', () => {
      expect(wrapper.text()).toContain('fix_pipeline/v1');
    });

    it('includes the workflow ID', () => {
      expect(wrapper.text()).toContain('#326');
    });
  });

  describe('status', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('displays the status returned by the query', () => {
      expect(findStatusIcon().props('status')).toBe('RUNNING');
    });

    it('displays the human-readable status', () => {
      expect(findStatusIcon().props('humanStatus')).toBe('running');
      expect(wrapper.text()).toContain('running');
    });
  });

  describe('accessibility', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('marks the status icon wrapper as aria-hidden', () => {
      expect(findStatusIcon().element.parentElement.getAttribute('aria-hidden')).toBe('true');
    });

    it('does not set aria-label on the session link since visible text is sufficient', () => {
      expect(findButton().attributes('aria-label')).toBeUndefined();
    });
  });

  describe('session link', () => {
    it('renders a button containing the status and chevron icon', async () => {
      createComponent();
      await waitForPromises();

      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toContain('running');
    });

    describe('when the link is clicked', () => {
      it('emits SHOW_SESSION via eventHub with the workflow id', async () => {
        const emitSpy = jest.spyOn(eventHub, '$emit');
        createComponent();
        await waitForPromises();

        await findButton().trigger('click');

        expect(emitSpy).toHaveBeenCalledWith(SHOW_SESSION, { id: 326 });
      });

      it('tracks the click via EventsTracker.trackClickThroughFlowWidget', async () => {
        createComponent();
        await waitForPromises();

        await findButton().trigger('click');

        expect(EventsTracker.trackClickThroughFlowWidget).toHaveBeenCalledWith({
          toolName: 'start_flow',
        });
      });
    });
  });

  describe('polling', () => {
    it('displays the status returned by the query', async () => {
      createComponent();
      await waitForPromises();

      expect(findStatusIcon().props('status')).toBe('RUNNING');
      expect(findStatusIcon().props('humanStatus')).toBe('running');
    });

    describe('when a terminal status is reached', () => {
      beforeEach(async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_FINISHED);

        createComponent();
        await waitForPromises();
      });

      it('displays the terminal status', () => {
        expect(findStatusIcon().props('status')).toBe('FINISHED');
        expect(findStatusIcon().props('humanStatus')).toBe('finished');
      });
    });
  });

  describe('plan rendering', () => {
    const expectedToolInfo = {
      name: 'todo_write',
      args: {
        todos: [
          { status: 'completed', description: 'Read pipeline logs' },
          { status: 'in_progress', description: 'Identify failing job' },
          { status: 'pending', description: 'Apply fix' },
        ],
      },
    };

    it('fetches the latest checkpoint using the workflow GraphQL ID', async () => {
      createComponent();
      await waitForPromises();

      expect(flowPlanHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, 326),
      });
    });

    describe('when the latest checkpoint has no todo_write message', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('does not render the plan', () => {
        expect(findTodoChecklist().exists()).toBe(false);
      });

      it('switches to the expanded card layout', () => {
        expect(findButton().classes()).toContain('gl-flex-col');
        expect(findButton().classes()).not.toContain('gl-inline-flex');
      });

      it('shows the activity title, tool name and content with an animated loader', () => {
        expect(findLatestActivity().text()).toContain('Read file');
        expect(findLatestActivityToolName().text()).toBe('read_file');
        expect(findLatestActivityDetail().text()).toContain('Reading file');
        expect(findAnimatedLoader().exists()).toBe(true);
      });
    });

    describe('when the session has no messages yet', () => {
      beforeEach(async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_EMPTY);

        createComponent();
        await waitForPromises();
      });

      it('falls back to the starting message with no detail', () => {
        expect(findLatestActivity().text()).toBe('Starting the session. Please wait');
        expect(findLatestActivityDetail().exists()).toBe(false);
        expect(findAnimatedLoader().exists()).toBe(true);
      });
    });

    describe('when a todo_write message is present', () => {
      beforeEach(async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_WITH_TODO);

        createComponent();
        await waitForPromises();
      });

      it('renders TodoChecklist with the parsed tool_info', () => {
        expect(findTodoChecklist().exists()).toBe(true);
        expect(findTodoChecklist().props('toolInfo')).toEqual(expectedToolInfo);
      });

      it('switches to the expanded card layout', () => {
        expect(findButton().classes()).toContain('gl-flex-col');
        expect(findButton().classes()).not.toContain('gl-inline-flex');
      });

      it('passes flowFinished as false while the flow is running', () => {
        expect(findTodoChecklist().props('flowFinished')).toBe(false);
      });
    });

    describe('when the flow is terminal and a plan is present', () => {
      beforeEach(async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_FINISHED_WITH_TODO);

        createComponent();
        await waitForPromises();
      });

      it('passes flowFinished as true once the flow is terminal', () => {
        expect(findTodoChecklist().exists()).toBe(true);
        expect(findTodoChecklist().props('flowFinished')).toBe(true);
      });
    });

    describe('when workflowId is absent', () => {
      beforeEach(async () => {
        createComponent({
          message: createMessageWithToolResponse(
            JSON.stringify({ status: 'started', flow_name: 'fix_pipeline/v1' }),
          ),
        });
        await waitForPromises();
      });

      it('does not fetch the plan', () => {
        expect(flowPlanHandler).not.toHaveBeenCalled();
      });
    });

    describe('when a terminal status is reached', () => {
      beforeEach(async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_FINISHED);

        createComponent();
        await waitForPromises();
      });

      it('does not show the latest activity', () => {
        expect(findLatestActivity().exists()).toBe(false);
      });

      it('keeps the pill layout', () => {
        expect(findButton().classes()).toContain('gl-inline-flex');
        expect(findButton().classes()).not.toContain('gl-flex-col');
      });
    });

    describe('checkpoint polling lifecycle', () => {
      const findCheckpointStopPolling = () =>
        jest.spyOn(wrapper.vm.$apollo.queries.checkpointMessages, 'stopPolling');

      it('stops polling once the checkpoint itself reports a terminal status', async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT_FINISHED);

        createComponent();
        const stopPolling = findCheckpointStopPolling();
        await waitForPromises();

        expect(stopPolling).toHaveBeenCalled();
      });

      it('keeps polling the checkpoint while it reports a non-terminal status', async () => {
        flowPlanHandler.mockResolvedValue(MOCK_LATEST_CHECKPOINT);

        createComponent();
        const stopPolling = findCheckpointStopPolling();
        await waitForPromises();

        expect(stopPolling).not.toHaveBeenCalled();
      });
    });

    it('captures GraphQL errors from the plan query in Sentry', async () => {
      const error = new Error('Plan query failed');
      flowPlanHandler.mockRejectedValue(error);

      createComponent();
      await waitForPromises();

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });
  });
});
