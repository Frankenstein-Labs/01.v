import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { logError } from '~/lib/logger';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import getProjectsDetailsQuery from 'ee/workspaces/common/graphql/queries/get_projects_details.query.graphql';
import agentWorkspacesListQuery from 'ee/workspaces/agent/graphql/queries/agent_workspaces_list.query.graphql';
import AgentWorkspacesList from 'ee/workspaces/agent/components/agent_workspaces_list.vue';
import { populateWorkspacesWithProjectDetails } from 'ee/workspaces/common/services/utils';
import WorkspacesList from 'ee/workspaces/common/components/workspaces_list/workspaces_list.vue';
import {
  AGENT_WORKSPACES_LIST_QUERY_RESULT,
  GET_PROJECTS_DETAILS_QUERY_RESULT,
} from '../../mock_data';

jest.mock('~/lib/logger');

Vue.use(VueApollo);

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';
const AGENT_NAME = 'agent-name';
const PROJECT_PATH = 'project/path';

describe('workspaces/agent/components/agent_workspaces_list.vue', () => {
  let wrapper;
  let mockApollo;
  let agentWorkspacesListQueryHandler;
  let getProjectsDetailsQueryHandler;

  const buildMockApollo = () => {
    agentWorkspacesListQueryHandler = jest
      .fn()
      .mockResolvedValueOnce(AGENT_WORKSPACES_LIST_QUERY_RESULT);
    getProjectsDetailsQueryHandler = jest
      .fn()
      .mockResolvedValueOnce(GET_PROJECTS_DETAILS_QUERY_RESULT);

    mockApollo = createMockApollo([
      [agentWorkspacesListQuery, agentWorkspacesListQueryHandler],
      [getProjectsDetailsQuery, getProjectsDetailsQueryHandler],
    ]);
  };
  const createWrapper = () => {
    // noinspection JSCheckFunctionSignatures
    wrapper = shallowMount(AgentWorkspacesList, {
      apolloProvider: mockApollo,
      provide: {
        emptyStateSvgPath: SVG_PATH,
      },
      propsData: {
        agentName: AGENT_NAME,
        projectPath: PROJECT_PATH,
      },
    });
  };

  const findWorkspacesList = () => wrapper.findComponent(WorkspacesList);

  beforeEach(() => {
    buildMockApollo();
  });

  describe('default (with nodes)', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('sets the workspaces prop of the workspaces list', () => {
      expect(findWorkspacesList().props('workspaces')).toEqual(
        populateWorkspacesWithProjectDetails(
          AGENT_WORKSPACES_LIST_QUERY_RESULT.data.project.clusterAgent.workspaces.nodes,
          GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
        ),
      );
    });

    it('does not call log error', () => {
      expect(logError).not.toHaveBeenCalled();
    });

    describe('when workspaces list emits page', () => {
      it('refetches workspaces starting at the specified cursor', async () => {
        const firstPageVariables = {
          first: 10,
          after: null,
          before: null,
        };
        const nextPageVariables = {
          after: 'end',
          first: 10,
        };

        createWrapper();
        await waitForPromises();

        expect(agentWorkspacesListQueryHandler).toHaveBeenCalledTimes(1);
        expect(agentWorkspacesListQueryHandler).toHaveBeenLastCalledWith({
          agentName: AGENT_NAME,
          projectPath: PROJECT_PATH,
          ...firstPageVariables,
        });

        findWorkspacesList().vm.$emit('page', nextPageVariables);

        await waitForPromises();

        expect(agentWorkspacesListQueryHandler).toHaveBeenCalledTimes(2);
        expect(agentWorkspacesListQueryHandler).toHaveBeenLastCalledWith({
          agentName: AGENT_NAME,
          projectPath: PROJECT_PATH,
          ...nextPageVariables,
        });
      });
    });
  });

  describe('when workspaces list emits error event', () => {
    const error = 'Failed to stop workspace';

    beforeEach(async () => {
      createWrapper();
      await waitForPromises();

      findWorkspacesList().vm.$emit('error', error);
    });

    it('sets the error for the workspaces list', async () => {
      await nextTick();

      expect(findWorkspacesList().props('error')).toBe(error);
    });

    describe('when workspaces list emits an empty error event', () => {
      it('dismisses the previous update error', async () => {
        expect(findWorkspacesList().props('error')).toBe(error);

        findWorkspacesList().vm.$emit('error', '');

        await nextTick();

        expect(findWorkspacesList().props('error')).toBe('');
      });
    });
  });

  describe.each`
    query                | queryHandlerFactory
    ${'userWorkspaces'}  | ${() => agentWorkspacesListQueryHandler}
    ${'projectsDetails'} | ${() => getProjectsDetailsQueryHandler}
  `('when $query query fails', ({ queryHandlerFactory }) => {
    const ERROR = new Error('Something bad!');

    beforeEach(async () => {
      const queryHandler = queryHandlerFactory();

      queryHandler.mockReset();
      queryHandler.mockRejectedValueOnce(ERROR);

      createWrapper();
      await waitForPromises();
    });

    it('sets the error prop of the workspaces list', () => {
      expect(findWorkspacesList().props('error')).toBe(
        'Unable to load current workspaces. Please try again or contact an administrator.',
      );
    });

    it('logs error', () => {
      expect(logError).toHaveBeenCalledWith(ERROR);
    });
  });
});
