import {
  FILTER_FIELD_PIPELINE_STATUS,
  FILTER_OPERATOR_IN,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
} from 'ee/ai/duo_agents_platform/constants';
import {
  TYPENAME_AI_CATALOG_ITEM_CONNECTION,
  TYPENAME_PROJECT,
  mockAgents,
  mockAgentsWithConfig,
  mockFlows,
  mockPageInfo,
  mockFlowsWithConfigs,
} from 'ee_jest/ai/catalog/mock_data';

export const buildPipelineHooksFilter = ({ operator = FILTER_OPERATOR_IN, value }) => ({
  [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value]: {
    rules: [{ field: FILTER_FIELD_PIPELINE_STATUS, operator, value }],
  },
});

export const mockProjectAgentsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: mockAgentsWithConfig,
        pageInfo: mockPageInfo,
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockProjectCatalogTabAgentsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: mockAgents,
        pageInfo: mockPageInfo,
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockProjectCatalogTabFlowsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: mockFlows,
        pageInfo: mockPageInfo,
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockProjectFlowsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: mockFlowsWithConfigs,
        pageInfo: mockPageInfo,
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};
