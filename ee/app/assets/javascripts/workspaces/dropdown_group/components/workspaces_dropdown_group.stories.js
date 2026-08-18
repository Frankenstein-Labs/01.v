import { GlDisclosureDropdown } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import userWorkspacesListQuery from '../../common/graphql/queries/user_workspaces_list.query.graphql';
import WorkspacesDropdownGroup from './workspaces_dropdown_group.vue';

const MOCK_WORKSPACES = [
  {
    __typename: 'Workspace',
    id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
    name: 'workspace-1-1-rfu27q',
    namespace: 'gl-rd-ns-1-1-rfu27q',
    desiredState: 'Running',
    actualState: 'Running',
    url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me',
    devfileRef: 'main',
    devfilePath: '.devfile.yaml',
    devfileWebUrl: 'http://localhost:3000/gitlab-org/gitlab/-/blob/main/.devfile.yaml',
    projectId: 'gid://gitlab/Project/1',
    createdAt: '2023-05-01T18:24:34Z',
  },
  {
    __typename: 'Workspace',
    id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
    name: 'workspace-1-1-idmi02',
    namespace: 'gl-rd-ns-1-1-idmi02',
    desiredState: 'Stopped',
    actualState: 'CreationRequested',
    url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me',
    devfileRef: 'main',
    devfilePath: '.devfile.yaml',
    devfileWebUrl: 'http://localhost:3000/gitlab-org/gitlab/-/blob/main/.devfile.yaml',
    projectId: 'gid://gitlab/Project/1',
    createdAt: '2023-04-29T18:24:34Z',
  },
];

export default {
  component: WorkspacesDropdownGroup,
  title: 'ee/workspaces/dropdown_group',
};

export const Default = (args, { argTypes }) => {
  return {
    components: { WorkspacesDropdownGroup, GlDisclosureDropdown },
    apolloProvider: createMockApollo([
      [
        userWorkspacesListQuery,
        () =>
          Promise.resolve({
            data: {
              currentUser: {
                id: 'gid://gitlab/User/1',
                workspaces: {
                  nodes: MOCK_WORKSPACES,
                  pageInfo: {
                    hasNextPage: false,
                    hasPreviousPage: false,
                    startCursor: null,
                    endCursor: null,
                  },
                },
              },
            },
          }),
      ],
    ]),
    provide: {
      glLicensedFeatures: {
        remoteDevelopment: true,
      },
    },
    props: Object.keys(argTypes),
    template: `<gl-disclosure-dropdown fluid-width toggle-text="Edit">
      <workspaces-dropdown-group supports-workspaces border-position="top" :new-workspace-path="newWorkspacePath" :project-id="projectId" :project-full-path="projectFullPath" />
    </gl-disclosure-dropdown>`,
  };
};

Default.args = {
  projectId: 1,
  projectFullPath: 'gitlab-org/gitlab',
  newWorkspacePath: '/create',
};
