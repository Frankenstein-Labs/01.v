import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapse, GlDisclosureDropdown } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SessionPillsBar from 'ee/ai/duo_agentic_chat/components/session_pills/session_pills_bar.vue';
import SessionPill from 'ee/ai/duo_agentic_chat/components/session_pills/session_pill.vue';
import getWorkflowsByIdsQuery from 'ee/ai/graphql/get_workflows_by_ids.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');

Vue.use(VueApollo);

const toGid = (id) => convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, id);

const buildStartFlowMessage = ({ workflowId, flowName, status = 'RUNNING' }) => ({
  message_type: 'tool',
  message_sub_type: 'start_flow',
  tool_info: {
    name: 'start_flow',
    tool_response: {
      content: JSON.stringify({
        workflow_id: workflowId,
        flow_name: flowName,
        status,
      }),
    },
  },
});

const buildWorkflowsByIdsResponse = (workflows) => ({
  data: {
    duoWorkflowWorkflows: {
      edges: workflows.map((w) => ({
        node: {
          id: toGid(w.id),
          status: w.status,
        },
      })),
    },
  },
});

describe('SessionPillsBar', () => {
  let wrapper;
  let workflowsByIdsHandler;
  let originalResizeObserver;

  beforeEach(() => {
    originalResizeObserver = global.ResizeObserver;
    global.ResizeObserver = jest.fn().mockImplementation(() => ({
      observe: jest.fn(),
      unobserve: jest.fn(),
      disconnect: jest.fn(),
    }));

    workflowsByIdsHandler = jest
      .fn()
      .mockResolvedValue(buildWorkflowsByIdsResponse([{ id: 326, status: 'RUNNING' }]));
  });

  afterEach(() => {
    global.ResizeObserver = originalResizeObserver;
  });

  const createComponent = ({ messages = [], handler = workflowsByIdsHandler } = {}) => {
    const apolloProvider = createMockApollo();
    apolloProvider.defaultClient.setRequestHandler(getWorkflowsByIdsQuery, handler);

    wrapper = shallowMountExtended(SessionPillsBar, {
      propsData: { messages },
      apolloProvider,
      // Rendered for real so the collapsed/expanded state is observable.
      stubs: { GlCollapse },
    });
  };

  const findBar = () => wrapper.findByTestId('session-pills-bar');
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findPills = () => wrapper.findAllComponents(SessionPill);
  const findOverflow = () => wrapper.findComponent(GlDisclosureDropdown);

  describe('initial render', () => {
    it('keeps the bar mounted but collapsed when there are no active sessions', () => {
      createComponent();

      expect(findBar().exists()).toBe(true);
      expect(findCollapse().props('visible')).toBe(false);
      expect(findBar().isVisible()).toBe(false);
    });

    it('renders no pills before the polled query resolves', () => {
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
      });

      expect(findPills()).toHaveLength(0);
    });

    it('does not fire the query when no start_flow messages are present', async () => {
      createComponent({ messages: [] });
      await waitForPromises();

      expect(workflowsByIdsHandler).not.toHaveBeenCalled();
      expect(findPills()).toHaveLength(0);
    });
  });

  describe('query variables', () => {
    it('passes the workflow ids extracted from start_flow messages as GIDs', async () => {
      createComponent({
        messages: [
          buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' }),
          buildStartFlowMessage({ workflowId: 327, flowName: 'fix_pipeline/v2' }),
        ],
      });
      await waitForPromises();

      expect(workflowsByIdsHandler).toHaveBeenCalledWith({
        ids: [toGid(326), toGid(327)],
      });
    });

    it('dedupes workflow ids that appear multiple times in messages', async () => {
      createComponent({
        messages: [
          buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' }),
          buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v2' }),
        ],
      });
      await waitForPromises();

      expect(workflowsByIdsHandler).toHaveBeenCalledWith({ ids: [toGid(326)] });
      expect(findPills()).toHaveLength(1);
      // Most recent occurrence wins for the flow name label.
      expect(findPills().at(0).props('flowName')).toBe('fix_pipeline/v2');
    });

    it('ignores chat messages that are not start_flow tool calls', async () => {
      createComponent({
        messages: [
          { message_type: 'user', message_sub_type: null, tool_info: null },
          buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' }),
        ],
      });
      await waitForPromises();

      expect(workflowsByIdsHandler).toHaveBeenCalledWith({ ids: [toGid(326)] });
    });

    it('handles malformed tool_response JSON gracefully', async () => {
      createComponent({
        messages: [
          {
            message_type: 'tool',
            message_sub_type: 'start_flow',
            tool_info: { tool_response: { content: 'not-json' } },
          },
        ],
      });
      await waitForPromises();

      expect(workflowsByIdsHandler).not.toHaveBeenCalled();
      expect(findPills()).toHaveLength(0);
    });
  });

  describe('pill rendering', () => {
    it('renders a pill for each non-terminal workflow returned by the query', async () => {
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
      });
      await waitForPromises();

      expect(findPills()).toHaveLength(1);
      expect(findPills().at(0).props()).toMatchObject({
        workflowId: 326,
        flowName: 'fix_pipeline/v1',
        status: 'RUNNING',
      });
    });

    it('filters out workflows in a terminal status returned by the query', async () => {
      workflowsByIdsHandler = jest.fn().mockResolvedValue(
        buildWorkflowsByIdsResponse([
          { id: 1, status: 'RUNNING' },
          { id: 2, status: 'FINISHED' },
          { id: 3, status: 'FAILED' },
          { id: 4, status: 'STOPPED' },
        ]),
      );
      createComponent({
        messages: [
          buildStartFlowMessage({ workflowId: 1, flowName: 'a' }),
          buildStartFlowMessage({ workflowId: 2, flowName: 'b' }),
          buildStartFlowMessage({ workflowId: 3, flowName: 'c' }),
          buildStartFlowMessage({ workflowId: 4, flowName: 'd' }),
        ],
      });
      await waitForPromises();

      expect(findPills()).toHaveLength(1);
      expect(findPills().at(0).props('workflowId')).toBe(1);
    });

    it('surfaces workflows awaiting user input ahead of merely active ones', async () => {
      workflowsByIdsHandler = jest.fn().mockResolvedValue(
        buildWorkflowsByIdsResponse([
          { id: 1, status: 'RUNNING' },
          { id: 2, status: 'INPUT_REQUIRED' },
          { id: 3, status: 'RUNNING' },
          { id: 4, status: 'PLAN_APPROVAL_REQUIRED' },
        ]),
      );
      createComponent({
        messages: [
          buildStartFlowMessage({ workflowId: 1, flowName: 'a' }),
          buildStartFlowMessage({ workflowId: 2, flowName: 'b' }),
          buildStartFlowMessage({ workflowId: 3, flowName: 'c' }),
          buildStartFlowMessage({ workflowId: 4, flowName: 'd' }),
        ],
      });
      await waitForPromises();

      const ids = findPills().wrappers.map((w) => w.props('workflowId'));
      expect(ids.slice(0, 2)).toEqual([2, 4]);
    });

    it('expands the bar once a session is active', async () => {
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
      });
      await waitForPromises();

      expect(findCollapse().props('visible')).toBe(true);
      expect(findBar().isVisible()).toBe(true);
    });

    it('collapses the bar again when the last workflow reaches a terminal status', async () => {
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
        handler: jest
          .fn()
          .mockResolvedValue(buildWorkflowsByIdsResponse([{ id: 326, status: 'FINISHED' }])),
      });
      await waitForPromises();

      expect(findPills()).toHaveLength(0);
      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('height-change event', () => {
    it('does not emit height-change on mount', () => {
      createComponent();

      expect(wrapper.emitted('height-change')).toBeUndefined();
    });

    // jsdom never fires `transitionend`, so drive the collapse hooks directly.
    it.each(['shown', 'hidden'])(
      'emits height-change when the collapse finishes transitioning (%s)',
      (event) => {
        createComponent();

        findCollapse().vm.$emit(event);

        expect(wrapper.emitted('height-change')).toHaveLength(1);
      },
    );
  });

  describe('click handling', () => {
    it('emits SHOW_SESSION via eventHub when a pill is clicked', async () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
      });
      await waitForPromises();

      findPills().at(0).vm.$emit('click', 326);

      expect(emitSpy).toHaveBeenCalledWith(SHOW_SESSION, { id: 326 });
    });
  });

  describe('error handling', () => {
    it('captures GraphQL errors in Sentry', async () => {
      const error = new Error('GraphQL error');
      createComponent({
        messages: [buildStartFlowMessage({ workflowId: 326, flowName: 'fix_pipeline/v1' })],
        handler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });
  });

  describe('overflow dropdown', () => {
    const messagesFor = (ids) =>
      ids.map((id) => buildStartFlowMessage({ workflowId: id, flowName: `flow_${id}` }));

    const responseFor = (ids) =>
      buildWorkflowsByIdsResponse(ids.map((id) => ({ id, status: 'RUNNING' })));

    it('renders no overflow dropdown when all pills fit', async () => {
      createComponent({
        messages: messagesFor([1, 2]),
        handler: jest.fn().mockResolvedValue(responseFor([1, 2])),
      });
      await waitForPromises();

      expect(findOverflow().exists()).toBe(false);
    });

    it('routes overflowed pills into the dropdown when container is constrained', async () => {
      // Stub getBoundingClientRect so each rendered pill reports ~120px and the
      // bar's measurePills() drives visibleCount through the real code path.
      const boundingRectSpy = jest
        .spyOn(Element.prototype, 'getBoundingClientRect')
        .mockReturnValue({ width: 120 });

      createComponent({
        messages: messagesFor([1, 2, 3]),
        handler: jest.fn().mockResolvedValue(responseFor([1, 2, 3])),
      });
      await waitForPromises();
      await nextTick();

      // Simulate the ResizeObserver firing with a constrained container width.
      wrapper.vm.handleResize({ contentRect: { width: 200 } });
      await nextTick();

      expect(findOverflow().exists()).toBe(true);
      expect(findOverflow().props('items')).toHaveLength(2);

      boundingRectSpy.mockRestore();
    });
  });
});
