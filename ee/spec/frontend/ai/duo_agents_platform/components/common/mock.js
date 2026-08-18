export const mockItems = [
  {
    id: 1,
    content: 'Starting workflow',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:00:00Z',
  },
  {
    id: 2,
    content: 'Processing data',
    messageType: 'assistant',
    status: 'success',
    timestamp: '2023-01-01T10:05:00Z',
  },
  {
    id: 3,
    content: 'Workflow completed',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:10:00Z',
  },
];

// Seeds the `getWorkflowPermissions` cache-only read. Mirrors the `edges { node }`
// shape the polling `getAgentFlow` query writes for the same normalized
// `DuoWorkflow` node — seeding as `nodes` would collide with that shape and
// trip Apollo's "Cache data may be lost" warning.
export const buildWorkflowPermissionsResponse = ({
  id = 'gid://gitlab/Ai::DuoWorkflows::Workflow/1',
  resumeDuoWorkflow = true,
  updateDuoWorkflow = true,
} = {}) => ({
  duoWorkflowWorkflows: {
    __typename: 'DuoWorkflowConnection',
    edges: [
      {
        __typename: 'DuoWorkflowEdge',
        node: {
          __typename: 'DuoWorkflow',
          id,
          userPermissions: {
            __typename: 'DuoWorkflowPermissions',
            updateDuoWorkflow,
            resumeDuoWorkflow,
          },
        },
      },
    ],
  },
});
