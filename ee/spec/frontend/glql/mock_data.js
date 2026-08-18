export const MOCK_ITERATION = {
  id: 'gid://gitlab/Iteration/1',
  iid: '1',
  startDate: '2024-10-01',
  dueDate: '2024-10-14',
  title: null,
  webUrl: 'https://gitlab.com/groups/gitlab-org/-/iterations/1',
  iterationCadence: {
    id: 'gid://gitlab/Iterations::Cadence/7001',
    title: 'testt',
    __typename: 'IterationCadence',
  },
  __typename: 'Iteration',
};

export const MOCK_ITERATION_MANUAL = {
  id: 'gid://gitlab/Iteration/3508',
  iid: '520',
  startDate: '2024-11-01',
  dueDate: '2024-11-30',
  title: 'Manual iteration',
  webUrl: 'https://gitlab.com/groups/gitlab-org/-/iterations/3508',
  iterationCadence: {
    id: 'gid://gitlab/Iterations::Cadence/7003',
    title: 'AAAA Manual iteration cadence',
    __typename: 'IterationCadence',
  },
  __typename: 'Iteration',
};
