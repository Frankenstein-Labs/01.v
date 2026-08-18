import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import WidgetAgentSessions from 'ee/vue_merge_request_widget/widgets/agent_sessions/index.vue';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnMergeRequestQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_merge_request.query.graphql';
import { buildSession } from 'ee_jest/ai/mocks';

Vue.use(VueApollo);

jest.mock('~/alert');

const buildQueryResponse = (nodes = []) => ({
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      mergeRequest: {
        __typename: 'MergeRequest',
        id: 'gid://gitlab/MergeRequest/1',
        duoWorkflows: {
          __typename: 'DuoWorkflowConnection',
          nodes,
        },
      },
    },
  },
});

describe('WidgetAgentSessions', () => {
  let wrapper;
  let queryHandler;

  const defaultMr = {
    iid: '1',
    targetProjectFullPath: 'namespace/project',
    sourceProjectFullPath: 'namespace/project',
  };

  const createComponent = ({ mr = {}, handler = queryHandler } = {}) => {
    const apolloProvider = createMockApollo([[getDuoAgentSessionsOnMergeRequestQuery, handler]]);

    wrapper = shallowMountExtended(WidgetAgentSessions, {
      apolloProvider,
      propsData: { mr: { ...defaultMr, ...mr } },
    });
  };

  const findSessionsList = () => wrapper.findComponent(AgentSessionsList);

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(buildQueryResponse());
  });

  describe('Apollo query', () => {
    it('uses targetProjectFullPath when available', () => {
      createComponent({ mr: { targetProjectFullPath: 'target/project' } });

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ projectPath: 'target/project', iid: '1' }),
      );
    });

    it('falls back to sourceProjectFullPath when targetProjectFullPath is absent', () => {
      createComponent({
        mr: { targetProjectFullPath: null, sourceProjectFullPath: 'source/project' },
      });

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ projectPath: 'source/project' }),
      );
    });

    it('skips the query when iid is not set', () => {
      createComponent({ mr: { iid: null } });

      expect(queryHandler).not.toHaveBeenCalled();
    });

    it('calls createAlert on query error', async () => {
      const error = new Error('GraphQL error');
      queryHandler = jest.fn().mockRejectedValue(error);
      createComponent();

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({ captureError: true, error }),
      );
    });
  });

  describe('AgentSessionsList', () => {
    it('is always rendered', () => {
      createComponent();
      expect(findSessionsList().exists()).toBe(true);
    });

    it('passes all fetched sessions to the list', async () => {
      const sessions = [
        buildSession({ id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1', status: 'RUNNING' }),
        buildSession({ id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/2', status: 'FINISHED' }),
      ];
      const handler = jest.fn().mockResolvedValue(buildQueryResponse(sessions));
      createComponent({ handler });
      await waitForPromises();

      expect(findSessionsList().props('sessions')).toEqual(sessions);
    });

    it('passes an empty sessions array before the query resolves', () => {
      createComponent();
      expect(findSessionsList().props('sessions')).toEqual([]);
    });

    it('passes isLoading=true while the query is in flight', () => {
      queryHandler = jest.fn().mockReturnValue(new Promise(() => {}));
      createComponent();

      expect(findSessionsList().props('isLoading')).toBe(true);
    });

    it('passes isLoading=false once the query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findSessionsList().props('isLoading')).toBe(false);
    });
  });
});
