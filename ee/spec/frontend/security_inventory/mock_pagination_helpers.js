import { subgroupsAndProjects, namespaceSecurityProjectsResponse } from './mock_data';

export const mockData = subgroupsAndProjects.data;
export const mockSearchData = namespaceSecurityProjectsResponse.data;

const defaultPageInfo = {
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
};

export const createGroupResponse = ({
  subgroups = mockData.group.descendantGroups.nodes || [],
  projects = mockData.group.projects.nodes || [],
  subgroupsPageInfo = {},
  projectsPageInfo = {},
} = {}) => ({
  data: {
    group: {
      ...mockData.group,
      descendantGroups: {
        nodes: subgroups,
        pageInfo: { ...defaultPageInfo, ...subgroupsPageInfo },
      },
      projects: {
        nodes: projects,
        pageInfo: { ...defaultPageInfo, ...projectsPageInfo },
      },
    },
  },
});

export const createSearchResponse = ({
  namespaceSecurityProjects = mockSearchData.namespaceSecurityProjects.edges || [],
  projectsPageInfo = {},
} = {}) => ({
  data: {
    group: {
      id: mockSearchData.group.id,
    },
    namespaceSecurityProjects: {
      edges: namespaceSecurityProjects,
      pageInfo: { ...defaultPageInfo, ...projectsPageInfo },
    },
  },
});

export const createPaginatedHandler = ({ first, second }) => {
  const handler = jest.fn();
  handler.mockResolvedValueOnce(createGroupResponse(first));
  handler.mockResolvedValueOnce(createGroupResponse(second));
  return handler;
};
