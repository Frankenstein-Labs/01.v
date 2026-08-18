const glqlViz = (glql) => ({
  type: 'Glql',
  options: {},
  data: {
    type: 'glql',
    query: {
      glql,
    },
  },
});

export const mockCustomDashboard = {
  id: 'gid://gitlab/Analytics::CustomDashboards::Dashboard/3',
  name: 'Custom dashboard',
  description: 'Custom dashboard with GLQL visualizations',
  config: {
    title: 'Custom dashboard',
    panels: [
      {
        title: 'Open issues',
        visualization: glqlViz('type = Issue AND state = opened'),
        gridAttributes: {
          xPos: 0,
          yPos: 0,
          width: 3,
          height: 1,
        },
      },
      {
        title: 'My merge requests',
        options: {},
        visualization: glqlViz('type = MergeRequest AND assignee = currentUser()'),
        gridAttributes: {
          xPos: 3,
          yPos: 0,
          width: 3,
          height: 1,
        },
      },
    ],
    version: '2',
    description: 'A very much more specific description',
  },
  organization: {
    id: 'gid://gitlab/Organizations::Organization/1',
    name: 'Fake organization',
    __typename: 'Organization',
  },
  namespace: null,
  createdBy: {
    id: 'gid://gitlab/User/1',
    name: 'Administrator',
    username: 'root',
    webUrl: 'http://gdk.test:3001/root',
    webPath: '/root',
    avatarUrl: 'https://www.gravatar.com/avatar/fake',
    __typename: 'UserCore',
  },
  createdAt: '2026-03-25T04:38:01Z',
  updatedAt: '2026-03-25T04:38:01Z',
  system: false,
  slug: null,
  __typename: 'CustomDashboard',
};

export const mockDashboardResponse = {
  customDashboard: mockCustomDashboard,
};
