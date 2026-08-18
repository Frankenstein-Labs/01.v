import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import PipelineAgentSessions from 'ee/ci/pipeline_details/header/components/pipeline_agent_sessions.vue';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import getDuoAgentSessionsOnPipelineQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_pipeline.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import { buildSession } from 'ee_jest/ai/mocks';

Vue.use(VueApollo);

jest.mock('~/alert');

const buildQueryResponse = (nodes = []) => ({
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      pipeline: {
        __typename: 'Pipeline',
        id: 'gid://gitlab/Ci::Pipeline/1',
        duoWorkflows: {
          __typename: 'DuoWorkflowConnection',
          nodes,
        },
      },
    },
  },
});

describe('PipelineAgentSessions', () => {
  let wrapper;
  let queryHandler;

  const defaultProvide = {
    paths: { fullProject: 'namespace/project' },
    pipelineIid: '1',
  };

  const createComponent = ({ provide = {}, handler = queryHandler } = {}) => {
    const apolloProvider = createMockApollo([[getDuoAgentSessionsOnPipelineQuery, handler]]);

    wrapper = shallowMountExtended(PipelineAgentSessions, {
      apolloProvider,
      provide: { ...defaultProvide, ...provide },
    });
  };

  const findSessionsList = () => wrapper.findComponent(AgentSessionsList);

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(buildQueryResponse());
  });

  describe('Apollo query', () => {
    it('passes projectPath and iid as variables', () => {
      createComponent();

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ projectPath: 'namespace/project', iid: '1' }),
      );
    });

    it('skips the query when pipelineIid is not set', () => {
      createComponent({ provide: { pipelineIid: '' } });

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

    it('does not surface the raw error message to the user', async () => {
      queryHandler = jest.fn().mockRejectedValue(new Error('Resolver blew up'));
      createComponent();

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({ message: 'Failed to load agent sessions for this pipeline.' }),
      );
    });
  });

  describe('SHOW_SESSION event', () => {
    it('refetches the sessions when the event is emitted', async () => {
      createComponent();
      await waitForPromises();
      expect(queryHandler).toHaveBeenCalledTimes(1);

      eventHub.$emit(SHOW_SESSION);
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
    });

    // Asserted through the hub rather than by emitting after destroy: a destroyed
    // component's refetch is a no-op, so an emit-based check passes even when the
    // listener is left behind.
    it('stops listening once the component is destroyed', () => {
      jest.spyOn(eventHub, '$off');
      createComponent();

      wrapper.destroy();

      expect(eventHub.$off).toHaveBeenCalledWith(SHOW_SESSION, expect.any(Function));
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
  });
});
