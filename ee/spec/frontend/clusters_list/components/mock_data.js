import {
  clusterAgentsResponse as clusterAgentsResponseCE,
  sharedAgentsResponse as sharedAgentsResponseCE,
  treeListResponseData as treeListResponseDataCE,
  expectedAgentsList as expectedAgentsListCE,
  clusterAgentsGroupResponse as clusterAgentsGroupResponseCE,
} from 'jest/clusters_list/components/mock_data';
import { agent, tokens, connections } from 'jest/clusters_list/mocks/apollo';

function extendAgentsWithReceptiveField(agentResponse) {
  const response = JSON.parse(JSON.stringify(agentResponse));
  const { project, group } = response.data;

  const addReceptiveField = (agentNode) => ({ ...agentNode, isReceptive: false });

  const updateAgents = (agentList) =>
    agentList.map((item) =>
      item.agent ? { agent: addReceptiveField(item.agent) } : addReceptiveField(item),
    );

  if (project) {
    if (project.clusterAgents) {
      project.clusterAgents = {
        nodes: updateAgents(project.clusterAgents.nodes),
        count: project.clusterAgents.nodes.length,
      };
    }
    if (project.ciAccessAuthorizedAgents) {
      project.ciAccessAuthorizedAgents.nodes = updateAgents(project.ciAccessAuthorizedAgents.nodes);
    }
    if (project.userAccessAuthorizedAgents) {
      project.userAccessAuthorizedAgents.nodes = updateAgents(
        project.userAccessAuthorizedAgents.nodes,
      );
    }
  }
  if (group) {
    group.clusterAgents = {
      nodes: updateAgents(group.clusterAgents.nodes),
      count: group.clusterAgents.nodes.length,
    };
  }

  return response;
}

export const clusterAgentsResponse = extendAgentsWithReceptiveField(clusterAgentsResponseCE);
export const clusterAgentsGroupResponse = extendAgentsWithReceptiveField(
  clusterAgentsGroupResponseCE,
);

export const sharedAgentsResponse = extendAgentsWithReceptiveField(sharedAgentsResponseCE);

export const treeListResponseData = treeListResponseDataCE;

export const expectedAgentsList = expectedAgentsListCE;

export const createAgentResponse = {
  data: {
    createClusterAgent: {
      clusterAgent: {
        ...agent,
        isReceptive: false,
        connections,
        tokens,
      },
      errors: [],
    },
  },
};

export const createAgentErrorResponse = {
  data: {
    createClusterAgent: {
      clusterAgent: {
        ...agent,
        isReceptive: false,
        connections,
        tokens,
      },
      errors: ['could not create agent'],
    },
  },
};
