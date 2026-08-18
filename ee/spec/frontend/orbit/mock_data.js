export const mockBasicSchema = {
  schema_version: 'v4.1',
  domains: [
    { name: 'ci', description: 'CI/CD domain', node_names: ['Job', 'Pipeline', 'Stage'] },
    { name: 'core', description: 'Core domain', node_names: ['User', 'Project'] },
  ],
  nodes: [
    { name: 'Job', domain: 'ci', description: 'A CI/CD job' },
    { name: 'Pipeline', domain: 'ci', description: 'A CI/CD pipeline' },
    { name: 'Stage', domain: 'ci', description: 'A pipeline stage' },
    { name: 'User', domain: 'core', description: 'A GitLab user' },
    { name: 'Project', domain: 'core', description: 'A GitLab project' },
  ],
  edges: [
    {
      name: 'AUTHORED',
      description: 'Authorship relationship',
      variants: [
        { source_type: 'User', target_type: 'Pipeline' },
        { source_type: 'User', target_type: 'Job' },
      ],
    },
    {
      name: 'CONTAINS',
      description: 'Containment relationship',
      variants: [{ source_type: 'Pipeline', target_type: 'Stage' }],
    },
  ],
};

export const mockExpandedSchema = {
  ...mockBasicSchema,
  nodes: [
    {
      name: 'Job',
      domain: 'ci',
      description: 'A CI/CD job',
      primary_key: 'id',
      label_field: 'name',
      properties: [
        { name: 'id', data_type: 'int64', nullable: false },
        { name: 'name', data_type: 'string', nullable: true },
        { name: 'status', data_type: 'string', nullable: false },
      ],
      style: { color: '#f59e0b', size: 30 },
    },
    {
      name: 'Pipeline',
      domain: 'ci',
      description: 'A CI/CD pipeline',
      primary_key: 'id',
      properties: [
        { name: 'id', data_type: 'int64', nullable: false },
        { name: 'ref', data_type: 'string', nullable: true },
      ],
      style: { color: '#f59e0b', size: 35 },
    },
    {
      name: 'Stage',
      domain: 'ci',
      description: 'A pipeline stage',
      properties: [],
      style: { color: '#fbbf24', size: 25 },
    },
    {
      name: 'User',
      domain: 'core',
      description: 'A GitLab user',
      properties: [
        { name: 'id', data_type: 'int64', nullable: false },
        { name: 'username', data_type: 'string', nullable: false },
      ],
      style: { color: '#ec4899', size: 30 },
    },
    {
      name: 'Project',
      domain: 'core',
      description: 'A GitLab project',
      properties: [{ name: 'id', data_type: 'int64', nullable: false }],
      style: { color: '#06b6d4', size: 30 },
    },
  ],
};

export const mockGroups = [
  {
    id: 'gid://gitlab/Group/1',
    name: 'Frontend',
    fullName: 'Frontend',
    fullPath: 'frontend',
    avatarUrl: null,
    knowledgeGraphEnabled: true,
    knowledgeGraphAvailable: true,
    maxAccessLevel: { integerValue: 50 },
  },
  {
    id: 'gid://gitlab/Group/2',
    name: 'Backend',
    fullName: 'Backend',
    fullPath: 'backend',
    avatarUrl: null,
    knowledgeGraphEnabled: false,
    knowledgeGraphAvailable: true,
    maxAccessLevel: { integerValue: 50 },
  },
];

export const mockNamespacesResponse = {
  data: {
    groups: {
      nodes: mockGroups,
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
    },
  },
};

export const mockQueryResponse = {
  data: {
    result: {
      nodes: [
        { type: 'User', id: 1, username: 'admin', name: 'Administrator' },
        { type: 'User', id: 2, username: 'dev', name: 'Developer' },
      ],
      edges: [],
      columns: [],
      row_count: 2,
    },
  },
};

export const mockNeighborResponse = {
  data: {
    result: {
      nodes: [
        { type: 'Project', id: 10, name: 'ProjectA' },
        { type: 'Project', id: 11, name: 'ProjectB' },
      ],
      edges: [
        { from: 'Group', from_id: 1, to: 'Project', to_id: 10, type: 'CONTAINS' },
        { from: 'Group', from_id: 1, to: 'Project', to_id: 11, type: 'CONTAINS' },
      ],
      columns: [],
    },
  },
};
