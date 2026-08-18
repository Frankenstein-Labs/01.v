import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import WorkItemAgentSessions from 'ee/work_items/components/agent_sessions/index.vue';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnWorkItemQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_work_item.query.graphql';
import { buildSession, buildWorkItemSessionsQueryResponse } from 'ee_jest/ai/mocks';
import { eventHub, SCROLL_TO_SESSIONS, requestScrollToSessions } from 'ee/ai/events/panel';

Vue.use(VueApollo);

jest.mock('~/alert');

const WORK_ITEM_ID = 'gid://gitlab/WorkItem/1';

const buildQueryResponse = (nodes = []) =>
  buildWorkItemSessionsQueryResponse({ workItemId: WORK_ITEM_ID, nodes });

describe('WorkItemAgentSessions', () => {
  let wrapper;
  let queryHandler;

  const createComponent = ({ workItemId = WORK_ITEM_ID, handler = queryHandler } = {}) => {
    wrapper = shallowMountExtended(WorkItemAgentSessions, {
      apolloProvider: createMockApollo([[getDuoAgentSessionsOnWorkItemQuery, handler]]),
      propsData: { workItemId },
    });
  };

  const findSessionsList = () => wrapper.findComponent(AgentSessionsList);

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(buildQueryResponse());
  });

  describe('Apollo query', () => {
    it('queries with the workItemId', () => {
      createComponent();

      expect(queryHandler).toHaveBeenCalledWith(expect.objectContaining({ id: WORK_ITEM_ID }));
    });

    it('skips the query when workItemId is not set', () => {
      createComponent({ workItemId: null });

      expect(queryHandler).not.toHaveBeenCalled();
    });

    it('calls createAlert on query error', async () => {
      const error = new Error('GraphQL error');
      createComponent({ handler: jest.fn().mockRejectedValue(error) });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({ captureError: true, error }),
      );
    });
  });

  afterEach(() => {
    eventHub.$off(SCROLL_TO_SESSIONS);
  });

  describe('AgentSessionsList', () => {
    it('is rendered while the query is in flight', () => {
      createComponent({ handler: jest.fn().mockReturnValue(new Promise(() => {})) });

      expect(findSessionsList().exists()).toBe(true);
      expect(findSessionsList().props('isLoading')).toBe(true);
    });

    it('passes all fetched sessions to the list', async () => {
      const sessions = [
        buildSession({ id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1', status: 'RUNNING' }),
        buildSession({ id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/2', status: 'FINISHED' }),
      ];
      createComponent({ handler: jest.fn().mockResolvedValue(buildQueryResponse(sessions)) });
      await waitForPromises();

      expect(findSessionsList().props('sessions')).toEqual(sessions);
    });

    it('passes isLoading=false once the query resolves', async () => {
      const sessions = [buildSession()];
      createComponent({ handler: jest.fn().mockResolvedValue(buildQueryResponse(sessions)) });
      await waitForPromises();

      expect(findSessionsList().props('isLoading')).toBe(false);
    });
  });

  describe('auto-scroll on SCROLL_TO_SESSIONS event', () => {
    let scrollIntoViewMock;

    beforeEach(() => {
      scrollIntoViewMock = jest.fn();
      Element.prototype.scrollIntoView = scrollIntoViewMock;
    });

    afterEach(() => {
      delete Element.prototype.scrollIntoView;
    });

    it('scrolls via sticky flag when component mounts after requestScrollToSessions', async () => {
      requestScrollToSessions();
      createComponent({
        handler: jest.fn().mockResolvedValue(buildQueryResponse([buildSession()])),
      });
      await waitForPromises();
      await nextTick();

      expect(scrollIntoViewMock).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'start',
      });
    });

    it('scrolls via eventHub when component is already mounted', async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(buildQueryResponse([buildSession()])),
      });
      await waitForPromises();

      eventHub.$emit(SCROLL_TO_SESSIONS);
      await nextTick();

      expect(scrollIntoViewMock).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'start',
      });
    });

    it('does not scroll when neither event nor sticky flag', async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(buildQueryResponse([buildSession()])),
      });
      await waitForPromises();
      await nextTick();

      expect(scrollIntoViewMock).not.toHaveBeenCalled();
    });

    it('does not scroll when sessions are empty', async () => {
      requestScrollToSessions();
      createComponent();
      await waitForPromises();
      await nextTick();

      expect(scrollIntoViewMock).not.toHaveBeenCalled();
    });
  });
});
