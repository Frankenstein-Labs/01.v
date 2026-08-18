import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import AgentTable from '~/clusters_list/components/agent_table.vue';
import Agents from '~/clusters_list/components/agents.vue';
import getAgentsQuery from 'ee/clusters_list/graphql/queries/get_agents.query.graphql';
import getSharedAgentsQuery from 'ee/clusters_list/graphql/queries/get_shared_agents.query.graphql';
import getTreeListQuery from '~/clusters_list/graphql/queries/get_tree_list.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('Agents', () => {
  let wrapper;

  const agentProject = {
    id: '1',
    fullPath: 'path/to/project',
    webUrl: 'https://gdk.test/path/to/project',
  };

  const agents = [
    {
      __typename: 'ClusterAgent',
      id: '1',
      name: 'agent-1',
      webPath: '/agent-1',
      createdAt: '2020-07-06T00:00:00.000Z',
      userAccessAuthorizations: null,
      connections: null,
      tokens: null,
      project: agentProject,
      isReceptive: true,
    },
    {
      __typename: 'ClusterAgent',
      id: '2',
      name: 'agent-2',
      webPath: '/agent-2',
      createdAt: '2020-07-06T00:00:00.000Z',
      userAccessAuthorizations: null,
      connections: null,
      tokens: null,
      isReceptive: false,
      project: agentProject,
    },
  ];

  const treeListResponseData = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        repository: {
          tree: {
            trees: { nodes: [] },
          },
        },
      },
    },
  };

  const expectedAgentsList = [
    {
      id: '1',
      name: 'agent-1',
      webPath: '/agent-1',
      status: 'unused',
      lastContact: null,
      connections: null,
      tokens: null,
      project: agentProject,
      isReceptive: true,
    },
    {
      id: '2',
      name: 'agent-2',
      webPath: '/agent-2',
      status: 'unused',
      lastContact: null,
      connections: null,
      tokens: null,
      project: agentProject,
      isReceptive: false,
    },
  ];

  const createWrapper = () => {
    const queryResponseData = {
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          clusterAgents: {
            nodes: agents,
            count: agents.length,
            connections: { nodes: [] },
            tokens: { nodes: [] },
          },
        },
      },
    };

    const sharedAgentsQueryResponseData = {
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          ciAccessAuthorizedAgents: { nodes: [] },
          userAccessAuthorizedAgents: { nodes: [] },
        },
      },
    };

    const agentQueryResponse = jest.fn().mockResolvedValue(queryResponseData);
    const sharedAgentsQueryResponse = jest.fn().mockResolvedValue(sharedAgentsQueryResponseData);
    const treeListQueryResponse = jest.fn().mockResolvedValue(treeListResponseData);

    const apolloProvider = createMockApollo(
      [
        [getAgentsQuery, agentQueryResponse],
        [getSharedAgentsQuery, sharedAgentsQueryResponse],
        [getTreeListQuery, treeListQueryResponse],
      ],
      {},
      { typePolicies: { Query: { fields: { project: { merge: true } } } } },
    );

    wrapper = shallowMount(Agents, {
      apolloProvider,
      propsData: { defaultBranchName: 'default' },
      provide: { fullPath: 'path/to/project', isGroup: false },
    });
  };

  const findAgentTable = () => wrapper.findComponent(AgentTable);

  describe('when there is a list of agents', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('should render agent table', () => {
      expect(findAgentTable().exists()).toBe(true);
    });

    it('should pass agent and folder info including `isReceptive` field to table component', () => {
      expect(findAgentTable().props('agents')).toMatchObject(expectedAgentsList);
    });
  });
});
