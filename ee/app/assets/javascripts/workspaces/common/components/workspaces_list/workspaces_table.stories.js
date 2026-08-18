import { WORKSPACE_STATES, WORKSPACE_DESIRED_STATES } from '../../constants';
import WorkspacesTable from './workspaces_table.vue';

const MOCK_WORKSPACES = Object.values(WORKSPACE_STATES).flatMap((actualState, i) =>
  Object.values(WORKSPACE_DESIRED_STATES).map((desiredState, j) => {
    const randomId = `${i}-${j}`;

    return {
      id: `gid://gitlab/RemoteDevelopment::Workspace/${randomId}`,
      projectName: 'GitLab.org / GitLab Development Kit',
      actualState,
      desiredState,
      devfileRef: 'main',
      devfilePath: '.devfile.yaml',
      url: 'https://60001-workspace-73241-3688647-4a3yqq.workspaces.gitlab.dev?folder=%2Fprojects%2Fgitlab-development-kit',
      name: `workspace-73241-3688647 ${actualState} - ${desiredState}`,
      createdAt: 1723834797000,
    };
  }),
);

const Template = (_, { argTypes }) => {
  return {
    components: { WorkspacesTable },
    provide: {
      emptyStateSvgPath: '',
    },
    props: Object.keys(argTypes),
    template: '<workspaces-table :workspaces="workspaces" />',
  };
};

export default {
  component: WorkspacesTable,
  title: 'ee/workspaces/workspaces_table',
};

export const Default = Template.bind({});

Default.args = {
  workspaces: MOCK_WORKSPACES,
};
