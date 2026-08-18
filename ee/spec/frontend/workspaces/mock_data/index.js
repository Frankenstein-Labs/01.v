import { cloneDeep } from 'lodash-es';
import { TEST_HOST } from 'helpers/test_constants';
import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from 'ee/workspaces/common/constants';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  AGENT_MAPPING_STATUS_UNMAPPED,
} from 'ee/workspaces/agent_mapping/constants';

export const WORKSPACE = {
  __typename: 'Workspace',
  id: 1,
  name: 'Workspace 1',
  namespace: 'Namespace',
  projectId: 'gid://gitlab/Project/1',
  desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
  actualState: WORKSPACE_STATES.starting,
  url: `${TEST_HOST}/workspace/1`,
  devfileRef: 'main',
  devfilePath: '.devfile.yaml',
  devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
  createdAt: '2023-05-01T18:24:34Z',
};

export const PROJECT_ID = 1;
export const PROJECT_FULL_PATH = 'gitlab-org/subgroup/gitlab';

export const WORKSPACE_QUERY_RESULT = {
  data: {
    workspace: cloneDeep(WORKSPACE),
  },
};

export const USER_WORKSPACES_LIST_QUERY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      workspaces: {
        nodes: [
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
            name: 'workspace-1-1-idmi02',
            namespace: 'gl-rd-ns-1-1-idmi02',
            desiredState: 'Stopped',
            actualState: 'CreationRequested',
            url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-04-29T18:24:34Z',
          },
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
            name: 'workspace-1-1-rfu27q',
            namespace: 'gl-rd-ns-1-1-rfu27q',
            desiredState: 'Running',
            actualState: 'Running',
            url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-05-01T18:24:34Z',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const USER_WORKSPACES_TAB_LIST_QUERY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      activeWorkspaces: {
        nodes: [
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
            name: 'workspace-1-1-idmi02',
            namespace: 'gl-rd-ns-1-1-idmi02',
            desiredState: 'Stopped',
            actualState: 'CreationRequested',
            url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-04-29T18:24:34Z',
          },
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
            name: 'workspace-1-1-rfu27q',
            namespace: 'gl-rd-ns-1-1-rfu27q',
            desiredState: 'Running',
            actualState: 'Running',
            url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-05-01T18:24:34Z',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
      terminatedWorkspaces: {
        nodes: [
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/4',
            name: 'workspace-1-1-iawi02',
            namespace: 'gl-rd-ns-1-1-iawi02',
            desiredState: 'Terminated',
            actualState: 'Terminated',
            url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-04-29T18:24:34Z',
          },
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/3',
            name: 'workspace-1-1-rsl27q',
            namespace: 'gl-rd-ns-1-1-rsl27q',
            desiredState: 'Terminated',
            actualState: 'Terminated',
            url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-05-01T18:24:34Z',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const GET_WORKSPACE_STATE_QUERY_RESULT = {
  data: {
    workspace: {
      id: '1',
      name: 'workspace-1-1-rfu27q',
      actualState: 'Running',
    },
  },
};

export const USER_WORKSPACES_TAB_LIST_QUERY_EMPTY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      activeWorkspaces: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
      terminatedWorkspaces: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const USER_WORKSPACES_LIST_QUERY_EMPTY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      workspaces: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const AGENT_WORKSPACES_LIST_QUERY_RESULT = {
  data: {
    project: {
      id: 1,
      clusterAgent: {
        id: 1,
        workspaces: {
          nodes: [
            {
              __typename: 'Workspace',
              id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
              name: 'workspace-1-1-idmi02',
              namespace: 'gl-rd-ns-1-1-idmi02',
              desiredState: 'Stopped',
              actualState: 'CreationRequested',
              url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
              devfileRef: 'main',
              devfilePath: '.devfile.yaml',
              devfileWebUrl:
                'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
              projectId: 'gid://gitlab/Project/1',
              createdAt: '2023-04-29T18:24:34Z',
            },
            {
              __typename: 'Workspace',
              id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
              name: 'workspace-1-1-rfu27q',
              namespace: 'gl-rd-ns-1-1-rfu27q',
              desiredState: 'Running',
              actualState: 'Running',
              url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
              devfileRef: 'main',
              devfilePath: '.devfile.yaml',
              devfileWebUrl:
                'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
              projectId: 'gid://gitlab/Project/1',
              createdAt: '2023-05-01T18:24:34Z',
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const AGENT_WORKSPACES_LIST_QUERY_EMPTY_RESULT = {
  data: {
    project: {
      id: 1,
      clusterAgent: {
        id: 1,
        workspaces: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const SEARCH_PROJECTS_QUERY_RESULT = {
  data: {
    projects: {
      nodes: [
        {
          id: 1,
          nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
          fullPath: 'gitlab-org/subgroup/gitlab',
          visibility: 'public',
        },
        {
          id: 2,
          nameWithNamespace: 'GitLab Org / Subgroup / GitLab Shell',
          fullPath: 'gitlab-org/subgroup/gitlab-shell',
          visibility: 'public',
        },
      ],
    },
  },
};

export const GET_PROJECT_DETAILS_QUERY_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
      repository: {
        rootRef: 'main',
      },
      group: {
        id: 'gid://gitlab/Group/80',
        fullPath: 'gitlab-org/subgroup',
      },
    },
  },
};

export const GET_DOT_DEVFILE_YAML_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      repository: {
        blobs: {
          nodes: [
            {
              id: 1,
              path: '.devfile.yaml',
              __typename: 'RepositoryBlob',
            },
            {
              id: 2,
              path: '.devfile.yml',
              __typename: 'RepositoryBlob',
            },
          ],
          __typename: 'RepositoryBlobConnection',
        },
        __typename: 'Repository',
      },
      __typename: 'Project',
    },
  },
};

export const GET_DOT_DEVFILE_YAML_RESULT_WITH_NO_RETURN_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      repository: {
        blobs: {
          nodes: [],
          __typename: 'RepositoryBlobConnection',
        },
        __typename: 'Repository',
      },
      __typename: 'Project',
    },
  },
};

export const GET_DOT_DEVFILE_FOLDER_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      repository: {
        __typename: 'Repository',
        tree: {
          __typename: 'Tree',
          blobs: {
            __typename: 'BlobConnection',
            edges: [
              {
                __typename: 'BlobEdge',
                node: {
                  id: 1,
                  __typename: 'Blob',
                  path: '.devfile/.devfile.1.yaml',
                },
              },
              {
                __typename: 'BlobEdge',
                node: {
                  id: 2,
                  __typename: 'Blob',
                  path: '.devfile/.devfile.2.yaml',
                },
              },
              {
                __typename: 'BlobEdge',
                node: {
                  id: 3,
                  __typename: 'Blob',
                  path: '.devfile/.gitkeep',
                },
              },
            ],
            pageInfo: {
              hasNextPage: true,
              endCursor: 'MTc',
            },
          },
        },
      },
    },
  },
};

export const GET_DOT_DEVFILE_FOLDER_RESULT_SECOND_CALL = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      repository: {
        __typename: 'Repository',
        tree: {
          __typename: 'Tree',
          blobs: {
            __typename: 'BlobConnection',
            edges: [
              {
                __typename: 'BlobEdge',
                node: {
                  id: 4,
                  __typename: 'Blob',
                  path: '.devfile/.devfile.aa.yaml',
                },
              },
            ],
            pageInfo: {
              hasNextPage: true,
              endCursor: 'MTc',
            },
          },
        },
      },
    },
  },
};

export const GET_DOT_DEVFILE_FOLDER_WITH_NO_RETURN_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      __typename: 'Project',
      repository: {
        __typename: 'Repository',
        tree: {
          __typename: 'Tree',
          blobs: {
            __typename: 'BlobConnection',
            edges: [],
          },
        },
      },
    },
  },
};

export const GET_PROJECTS_DETAILS_QUERY_RESULT = {
  data: {
    projects: {
      nodes: [
        {
          id: 'gid://gitlab/Project/1',
          nameWithNamespace: 'Gitlab Org / Gitlab Shell',
          __typename: 'Project',
        },
      ],
      __typename: 'ProjectConnection',
    },
  },
};

export const GET_WORKSPACES_NAMESPACE_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS = {
  data: {
    namespaceAgents: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      workspacesClusterAgents: {
        nodes: [],
      },
    },
  },
};

export const GET_WORKSPACES_ORGANIZATION_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS = {
  data: {
    organizationAgents: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      workspacesClusterAgents: {
        nodes: [],
      },
    },
  },
};

export const GET_WORKSPACES_NAMESPACE_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS = {
  data: {
    namespaceAgents: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      workspacesClusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/1',
            name: 'root-group-agent',
            project: {
              id: 'gid://gitlab/Project/101',
              nameWithNamespace: 'GitLab Org / GitLab Agent One',
            },
            workspacesAgentConfig: {
              id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/999',
            },
          },
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'root-group-agent-2',
            project: {
              id: 'gid://gitlab/Project/102',
              nameWithNamespace: 'GitLab Org / GitLab Agent Two',
            },
            workspacesAgentConfig: {
              id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/998',
            },
          },
        ],
      },
    },
  },
};

export const TRANSFORMED_GET_WORKSPACES_NAMESPACE_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS = [
  {
    text: 'GitLab Org / GitLab Agent One / root-group-agent',
    value: 'gid://gitlab/Clusters::Agent/1',
  },
  {
    text: 'GitLab Org / GitLab Agent Two / root-group-agent-2',
    value: 'gid://gitlab/Clusters::Agent/2',
  },
];

export const GET_WORKSPACES_ORGANIZATION_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS = {
  data: {
    organizationAgents: {
      id: 'gid://gitlab/Organizations::Organization/1',
      workspacesClusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'root-group-agent-2',
            project: {
              id: 'gid://gitlab/Project/102',
              nameWithNamespace: 'GitLab Org / GitLab Agent Two',
            },
            workspacesAgentConfig: {
              id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/998',
            },
          },
          {
            id: 'gid://gitlab/Clusters::Agent/3',
            name: 'org-agent-1',
            project: null,
            workspacesAgentConfig: {
              id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/999',
            },
          },
        ],
      },
    },
  },
};

export const TRANSFORMED_GET_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT_ORG_AND_NAMESPACE_AGENTS = [
  {
    text: 'GitLab Org / GitLab Agent Two / root-group-agent-2',
    value: 'gid://gitlab/Clusters::Agent/2',
  },
  {
    text: 'org-agent-1',
    value: 'gid://gitlab/Clusters::Agent/3',
  },
  {
    text: 'GitLab Org / GitLab Agent One / root-group-agent',
    value: 'gid://gitlab/Clusters::Agent/1',
  },
];

export const MAPPED_CLUSTER_AGENT = {
  id: 'gid://gitlab/Clusters::Agent/1',
  name: 'root-group-agent',
  project: {
    id: 'gid://gitlab/Project/101',
    name: 'GitLab Agent One',
  },
  connections: {
    nodes: [
      {
        connectedAt: '2023-04-29T18:24:34Z',
      },
    ],
  },
  mappingStatus: AGENT_MAPPING_STATUS_MAPPED,
  workspacesAgentConfig: {
    id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/999',
  },
};

export const UNMAPPED_CLUSTER_AGENT = {
  id: 'gid://gitlab/Clusters::Agent/2',
  name: 'root-group-agent-2',
  project: {
    id: 'gid://gitlab/Project/102',
    name: 'GitLab Agent Two',
  },
  connections: {
    nodes: [
      {
        connectedAt: '2023-04-29T18:24:34Z',
      },
    ],
  },
  mappingStatus: AGENT_MAPPING_STATUS_UNMAPPED,
  workspacesAgentConfig: {
    id: 'gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/999',
  },
};

export const GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/81',
      mappedAgents: {
        nodes: [cloneDeep(MAPPED_CLUSTER_AGENT)],
      },
      unmappedAgents: {
        nodes: [cloneDeep(UNMAPPED_CLUSTER_AGENT)],
      },
    },
  },
};

export const BLOB_CONTENT_QUERY_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      repository: { blobs: { nodes: [{ id: 'blob-1', rawBlob: 'some: yaml' }] } },
    },
  },
};
export const DEVFILE_VALIDATE_MUTATION_RESULT = {
  data: {
    devfileValidate: {
      errors: [],
      valid: true,
    },
  },
};
export const WORKSPACE_CREATE_MUTATION_RESULT = {
  data: {
    workspaceCreate: {
      errors: [],
      workspace: {
        ...cloneDeep(WORKSPACE),
        id: 2,
      },
    },
  },
};

export const WORKSPACE_UPDATE_MUTATION_RESULT = {
  data: {
    workspaceUpdate: {
      errors: [],
      workspace: {
        __typename: 'Workspace',
        id: WORKSPACE.id,
        actualState: WORKSPACE_STATES.running,
        desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
      },
    },
  },
};

export const CREATE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    namespaceCreateRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: [],
      namespaceClusterAgentMapping: {
        id: '321',
        namespaceId: 'gid://gitlab/Namespace/2',
        clusterAgentId: 'gid://gitlab/Clusters::Agent/2',
        creatorId: 'gid://gitlab/User/1',
        createdAt: '2025-03-24T12:16:48Z',
        updatedAt: '2025-03-26T20:15:04Z',
      },
    },
  },
};

export const CREATE_CLUSTER_AGENT_MAPPING_MUTATION_WITH_ERROR_RESULT = {
  data: {
    namespaceCreateRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: ['Namespace cluster agent mapping already exists'],
      namespaceClusterAgentMapping: null,
    },
  },
};

export const DELETE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    namespaceDeleteRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: [],
      namespaceClusterAgentMapping: {
        id: '321',
        namespaceId: 'gid://gitlab/Namespace/2',
        clusterAgentId: 'gid://gitlab/Clusters::Agent/2',
        creatorId: 'gid://gitlab/User/1',
        createdAt: '2025-03-24T12:16:48Z',
        updatedAt: '2025-03-26T20:15:04Z',
      },
    },
  },
};

export const DELETE_CLUSTER_AGENT_MAPPING_MUTATION_WITH_ERROR_RESULT = {
  data: {
    namespaceDeleteRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: ['Namespace cluster agent mapping not found'],
      namespaceClusterAgentMapping: null,
    },
  },
};

export const NAMESPACE_ID = 'gid://gitlab/Group/81';

// these values correspond to ORGANIZATION_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT
export const ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT = {
  data: {
    organization: {
      id: 'gid://gitlab/Organizations::Organization/1',
      mappedAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/14',
          },
          {
            id: 'gid://gitlab/Clusters::Agent/12',
          },
          {
            id: 'gid://gitlab/Clusters::Agent/10',
          },
          {
            id: 'gid://gitlab/Clusters::Agent/17',
          },
        ],
      },
    },
  },
};

export const ORGANIZATION_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT = {
  data: {
    organization: {
      id: 'gid://gitlab/Organizations::Organization/1',
      organizationWorkspacesClusterAgents: {
        nodes: [
          /**
           * Connection status: Not connected
           * Workspaces agent config: enabled
           * Availability: available
           */
          {
            id: 'gid://gitlab/Clusters::Agent/14',
            name: 'midnightowlgarden',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/midnightowlgarden',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: {
              id: '',
              enabled: true,
            },
            connections: {
              nodes: [],
            },
          },
          /**
           * Connection status: Not connected
           * Workspaces agent config: enabled
           * Availability: blocked
           */
          {
            id: 'gid://gitlab/Clusters::Agent/13',
            name: 'coastalechovalley',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/coastalechovalley',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: {
              id: '',
              enabled: true,
            },
            connections: {
              nodes: [],
            },
          },
          /**
           * Connection status: Not connected
           * Workspaces agent config: not enabled
           * Availability: available
           */
          {
            id: 'gid://gitlab/Clusters::Agent/12',
            name: 'wandingbreezetale',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/wandingbreezetale',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: null,
            connections: {
              nodes: [],
            },
          },
          /**
           * Connection status: Not connected
           * Workspaces agent config: not enabled
           * Availability: blocked
           */
          {
            id: 'gid://gitlab/Clusters::Agent/11',
            name: 'crimsonmapleshadow',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/crimsonmapleshadow',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: null,
            connections: {
              nodes: [],
            },
          },
          /**
           * Connection status: Connected
           * Workspaces agent config: enabled
           * Availability: available
           */
          {
            id: 'gid://gitlab/Clusters::Agent/10',
            name: 'meadowsageharbor',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/meadowsageharbor',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: {
              id: '',
              enabled: true,
            },
            connections: {
              nodes: [
                {
                  connectedAt: '2023-04-29T18:24:34Z',
                },
              ],
            },
          },
          /**
           * Connection status: Connected
           * Workspaces agent config: enabled
           * Availability: blocked
           */
          {
            id: 'gid://gitlab/Clusters::Agent/16',
            name: 'silvermoonharbor',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/silvermoonharbor',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: {
              id: '',
              enabled: true,
            },
            connections: {
              nodes: [
                {
                  connectedAt: '2023-04-29T18:24:34Z',
                },
              ],
            },
          },
          /**
           * Connection status: Connected
           * Workspaces agent config: not enabled
           * Availability: available
           */
          {
            id: 'gid://gitlab/Clusters::Agent/17',
            name: 'silvermoonharbor',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/silvermoonharbor',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: null,
            connections: {
              nodes: [
                {
                  connectedAt: '2023-04-29T18:24:34Z',
                },
              ],
            },
          },
          /**
           * Connection status: Connected
           * Workspaces agent config: not enabled
           * Availability: blocked
           */
          {
            id: 'gid://gitlab/Clusters::Agent/18',
            name: 'oceanbreezecliff',
            webPath: '/gitlab-org/gitlab-agent-configurations/-/cluster_agents/oceanbreezecliff',
            project: {
              id: 'gid://gitlab/Project/19',
              name: 'gitlab-agent-configurations',
              group: {
                id: 'gid://gitlab/Group/24',
                name: 'Gitlab Org',
              },
            },
            workspacesAgentConfig: null,
            connections: {
              nodes: [
                {
                  connectedAt: '2023-04-29T18:24:34Z',
                },
              ],
            },
          },
        ],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'eyJpZCI6IjE0In0',
          endCursor: 'eyJpZCI6IjEwIn0',
        },
      },
    },
  },
};

export const CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    organizationCreateClusterAgentMapping: {
      errors: [],
    },
  },
};

export const CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR = {
  data: {
    organizationCreateClusterAgentMapping: {
      errors: ['Cluster agent mapping already exists'],
    },
  },
};

export const DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    organizationDeleteClusterAgentMapping: {
      errors: [],
    },
  },
};

export const DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR = {
  data: {
    organizationDeleteClusterAgentMapping: {
      errors: ['Organization cluster agent mapping not found'],
    },
  },
};
