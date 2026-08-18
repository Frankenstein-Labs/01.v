export const refMock = 'default-ref';

export const codeOwnersPath = 'path/to/codeowners/file';

export const codeOwnersMock = [
  { id: '1', name: 'Idella Welch', webPath: '/raisa' },
  { id: '2', name: 'Winston Von', webPath: '/noella' },
  { id: '3', name: 'Don Runte', webPath: '/edyth' },
  { id: '4', name: 'Sherri McClure', webPath: '/julietta_rogahn' },
  { id: '5', name: 'Amber Koch', webPath: '/youlanda' },
  { id: '6', name: 'Van Schmitt', webPath: '/hortensia' },
  { id: '7', name: 'Larita Hamill', webPath: '/alesia' },
];

export const codeOwnersPropsMock = {
  projectPath: 'some/project',
  filePath: 'some/file',
  branch: 'main',
  branchRulesPath: '/some/Project/-/settings/repository#branch-rules',
  canViewBranchRules: true,
};

export const headerAppInjected = {
  canCollaborate: true,
  canEditTree: true,
  canPushCode: true,
  canPushToBranch: true,
  originalBranch: 'main',
  selectedBranch: 'feature/new-ui',
  newBranchPath: '/project/new-branch',
  newTagPath: '/project/new-tag',
  newBlobPath: '/project/new-file',
  forkNewBlobPath: '/project/fork/new-file',
  forkNewDirectoryPath: '/project/fork/new-directory',
  forkUploadBlobPath: '/project/fork/upload',
  uploadPath: '/project/upload',
  newDirPath: '/project/new-directory',
  projectRootPath: '/project/root/path',
  comparePath: undefined,
  isReadmeView: false,
  isFork: false,
  needsToFork: true,
  isGitpodEnabledForUser: false,
  isBlob: true,
  showEditButton: true,
  showWebIdeButton: true,
  isGitpodEnabledForInstance: false,
  showPipelineEditorButton: true,
  webIdeUrl: 'https://gitlab.com/project/-/ide/',
  editUrl: 'https://gitlab.com/project/-/edit/main/',
  pipelineEditorUrl: 'https://gitlab.com/project/-/ci/editor',
  gitpodUrl: 'https://app.ona.com/#https://gitlab.com/project',
  userPreferencesGitpodPath: '/profile/preferences#gitpod',
  userProfileEnableGitpodPath: '/profile/preferences?enable_gitpod=true',
  httpUrl: 'https://gitlab.com/example-group/example-project.git',
  xcodeUrl: 'xcode://clone?repo=https://gitlab.com/example-group/example-project.git',
  sshUrl: 'git@gitlab.com:example-group/example-project.git',
  kerberosUrl: 'https://kerberos@gitlab.com/example-group/example-project.git',
  downloadLinks: [
    {
      text: 'zip',
      path: 'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.zip',
    },
    {
      text: 'tar.gz',
      path: 'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.tar.gz',
    },
    {
      text: 'tar.bz2',
      path: 'https://gitlab.com/example-group/example-project/-/archive/main/example-project-main.tar.bz2',
    },
    {
      text: 'tar',
      path: 'https://gitlab.com/example-group/example-project/-/releases',
    },
  ],
  downloadArtifacts: [
    'https://gitlab.com/example-group/example-project/-/jobs/artifacts/main/download?job=build',
  ],
  isBinary: false,
  rootRef: 'main',
  newWorkspacePath: '/workspaces/new',
  showNoSshKeyMessage: false,
  userSettingsSshKeysPath: '',
};

export const userPermissionsMock = {
  pushCode: true,
  forkProject: true,
  downloadCode: true,
  createMergeRequestIn: true,
  createPathLock: true,
  __typename: 'ProjectPermissions',
};

export const getProjectMockWithOverrides = ({
  userPermissionsOverride = {},
  pathLockNodesOverride = null,
} = {}) => ({
  __typename: 'Project',
  id: 'gid://gitlab/Project/7',
  userPermissions: { ...userPermissionsMock, ...userPermissionsOverride },
  pathLocks: {
    __typename: 'PathLockConnection',
    nodes:
      pathLockNodesOverride !== null
        ? pathLockNodesOverride
        : [
            {
              __typename: 'PathLock',
              id: 'gid://gitlab/PathLock/2',
              path: 'some/file.js',
              createdAt: '2026-07-13T00:00:00Z',
              user: {
                id: 'gid://gitlab/User/1',
                username: 'root',
                name: 'Administrator',
                avatarUrl: 'https://www.gravatar.com/avatar/root?s=80',
                webPath: '/root',
                __typename: 'UserCore',
              },
              userPermissions: {
                destroyPathLock: true,
              },
            },
          ],
  },
  repository: {
    __typename: 'Repository',
    empty: false,
    rootRef: 'main',
  },
});

export const projectMock = getProjectMockWithOverrides();

export const exactDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/1',
  path: 'test/component',
  createdAt: '2026-07-13T00:00:00Z',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
    avatarUrl: 'https://www.gravatar.com/avatar/user2?s=80',
    webPath: '/user2',
  },
  userPermissions: {
    destroyPathLock: true,
  },
};

export const upstreamDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/3',
  path: 'test',
  createdAt: '2026-07-13T00:00:00Z',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
    avatarUrl: 'https://www.gravatar.com/avatar/user2?s=80',
    webPath: '/user2',
  },
  userPermissions: {
    destroyPathLock: true,
  },
};

export const downstreamDirectoryLock = {
  __typename: 'PathLock',
  id: 'gid://gitlab/PathLock/2',
  path: 'test/component/icon',
  createdAt: '2026-07-13T00:00:00Z',
  user: {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
    avatarUrl: 'https://www.gravatar.com/avatar/user2?s=80',
    webPath: '/user2',
  },
  userPermissions: {
    destroyPathLock: true,
  },
};

export const userMock = {
  data: {
    currentUser: {
      __typename: 'CurrentUser',
      id: 'gid://gitlab/User/1',
      username: 'root',
      name: 'Administrator',
      avatarUrl: 'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80',
      webUrl: '/root',
      webPath: '/root',
    },
  },
};

export const lockPathMutationMock = {
  data: {
    projectSetLocked: {
      project: {
        id: 'gid://gitlab/Project/28',
        pathLocks: {
          nodes: [
            {
              id: 'gid://gitlab/PathLock/26',
              path: 'test/component',
              __typename: 'PathLock',
            },
          ],
          __typename: 'PathLockConnection',
        },
        __typename: 'Project',
      },
      errors: [],
      __typename: 'ProjectSetLockedPayload',
    },
  },
};

export const blobControlsDataMock = {
  __typename: 'Project',
  id: '1234',
  userPermissions: userPermissionsMock,
  repository: {
    __typename: 'Repository',
    empty: false,
    blobs: {
      __typename: 'RepositoryBlobConnection',
      nodes: [
        {
          __typename: 'RepositoryBlob',
          id: '5678',
          name: 'file.js',
          blamePath: 'blame/file.js',
          permalinkPath: 'permalink/file.js',
          path: 'some/file.js',
          storedExternally: false,
          externalStorage: 'https://external-storage',
          environmentFormattedExternalUrl: '',
          environmentExternalUrlForRouteMap: '',
          rawPath: 'https://testing.com/flightjs/flight/snippets/51/raw',
          rawTextBlob: 'Example raw text content',
          archived: false,
          replacePath: 'some/replace/file.js',
          webPath: 'some/file.js',
          canCurrentUserPushToBranch: true,
          canModifyBlob: true,
          canModifyBlobWithWebIde: true,
          forkAndViewPath: 'fork/view/path',
          editBlobPath: 'https://edit/blob/path/file.js',
          ideEditPath: 'https://ide/blob/path/file.js',
          pipelineEditorPath: 'pipeline/editor/path/file.yml',
          gitpodBlobUrl: 'gitpod/blob/url/file.js',
          simpleViewer: {
            __typename: 'BlobViewer',
            collapsed: false,
            loadingPartialName: 'loading',
            renderError: null,
            tooLarge: false,
            type: 'simple',
            fileType: 'rich',
          },
          richViewer: {
            __typename: 'BlobViewer',
            collapsed: false,
            loadingPartialName: 'loading',
            renderError: 'too big file',
            tooLarge: false,
            type: 'rich',
            fileType: 'rich',
          },
        },
      ],
    },
  },
};

export const currentUserDataMock = {
  __typename: 'User',
  id: '1234',
  gitpodEnabled: true,
  preferencesGitpodPath: 'preferences/gitpod/path',
  profileEnableGitpodPath: 'profile/enable/gitpod/path',
};

export const simpleViewerMock = {
  __typename: 'RepositoryBlob',
  id: '1',
  name: 'some_file.js',
  size: 123,
  rawSize: 123,
  rawTextBlob: 'raw content',
  fileType: 'text',
  language: 'javascript',
  path: 'some_file.js',
  webPath: 'some_file.js',
  blamePath: 'blame/file.js',
  editBlobPath: 'some_file.js/edit',
  gitpodBlobUrl: 'https://app.ona.com#path/to/blob.js',
  ideEditPath: 'some_file.js/ide/edit',
  forkAndEditPath: 'some_file.js/fork/edit',
  ideForkAndEditPath: 'some_file.js/fork/ide',
  forkAndViewPath: 'some_file.js/fork/view',
  codeNavigationPath: '',
  projectBlobPathRoot: '',
  environmentFormattedExternalUrl: '',
  environmentExternalUrlForRouteMap: '',
  canModifyBlob: true,
  canModifyBlobWithWebIde: true,
  canCurrentUserPushToBranch: true,
  archived: false,
  storedExternally: false,
  externalStorageUrl: '',
  externalStorage: 'lfs',
  rawPath: 'some_file.js',
  replacePath: 'some_file.js/replace',
  pipelineEditorPath: 'path/to/pipeline/editor',
  simpleViewer: {
    fileType: 'text',
    tooLarge: false,
    type: 'simple',
    renderError: null,
  },
  richViewer: null,
};

export const richViewerMock = {
  ...simpleViewerMock,
  richViewer: {
    fileType: 'markup',
    tooLarge: false,
    type: 'rich',
    renderError: null,
  },
};

export const propsMock = { path: 'some_file.js', projectPath: 'some/path' };

export const axiosMockResponse = { html: 'text', binary: true };

export const FILE_SIZE_3MB = `3000000`;
