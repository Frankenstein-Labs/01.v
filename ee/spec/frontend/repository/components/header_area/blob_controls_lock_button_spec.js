import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BlobControlsLockButton from 'ee_component/repository/components/header_area/blob_controls_lock_button.vue';
import LockButton from 'ee_component/repository/components/header_area/lock_button.vue';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import { getProjectMockWithOverrides } from 'ee_jest/repository/mock_data';

Vue.use(VueApollo);

describe('BlobControlsLockButton component', () => {
  let wrapper;
  let fakeApollo;

  const projectInfoResolverMock = jest.fn();

  const createPathLockNode = (path) => ({
    __typename: 'PathLock',
    id: 'gid://gitlab/PathLock/2',
    path,
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
  });

  const createComponent = async ({ provide = {}, pathLockNodes } = {}) => {
    projectInfoResolverMock.mockResolvedValue({
      data: {
        project: getProjectMockWithOverrides({
          pathLockNodesOverride: pathLockNodes ?? [],
        }),
      },
    });

    fakeApollo = createMockApollo([[projectInfoQuery, projectInfoResolverMock]]);

    wrapper = shallowMountExtended(BlobControlsLockButton, {
      apolloProvider: fakeApollo,
      provide: {
        glFeatures: { repositoryLockInformation: true },
        glLicensedFeatures: { fileLocks: true },
        ...provide,
      },
      propsData: {
        projectPath: 'some/project',
        path: 'some/file.js',
      },
    });

    await waitForPromises();
  };

  const findLockButton = () => wrapper.findComponent(LockButton);

  afterEach(() => {
    fakeApollo = null;
    projectInfoResolverMock.mockReset();
  });

  it('renders the lock button when the feature flag and licensed feature are enabled', async () => {
    await createComponent();

    expect(findLockButton().exists()).toBe(true);
    expect(findLockButton().props()).toMatchObject({
      projectPath: 'some/project',
      path: 'some/file.js',
    });
  });

  it('does not render the lock button when `repositoryLockInformation` feature flag is disabled', async () => {
    await createComponent({
      provide: { glFeatures: { repositoryLockInformation: false } },
    });

    expect(findLockButton().exists()).toBe(false);
    expect(projectInfoResolverMock).not.toHaveBeenCalled();
  });

  it('does not render the lock button when `fileLocks` licensed feature is not available', async () => {
    await createComponent({
      provide: { glLicensedFeatures: { fileLocks: false } },
    });

    expect(findLockButton().exists()).toBe(false);
    expect(projectInfoResolverMock).not.toHaveBeenCalled();
  });

  it('passes the default lock state to the lock button when the file is not locked', async () => {
    await createComponent();

    expect(findLockButton().props()).toMatchObject({
      isLocked: false,
      lockUser: null,
      lockedAt: null,
      canDestroyLock: false,
      canCreateLock: true,
    });
  });

  it('passes the lock state to the lock button when the current file is locked', async () => {
    await createComponent({
      pathLockNodes: [createPathLockNode('some/file.js')],
    });

    expect(findLockButton().props()).toMatchObject({
      isLocked: true,
      lockUser: expect.objectContaining({ username: 'root' }),
      lockedAt: '2026-07-13T00:00:00Z',
      canDestroyLock: true,
      canCreateLock: true,
    });
  });

  it('passes the default lock state to the lock button when a different file is locked', async () => {
    await createComponent({
      pathLockNodes: [createPathLockNode('some/other_file.js')],
    });

    expect(findLockButton().props()).toMatchObject({
      isLocked: false,
      lockUser: null,
      lockedAt: null,
      canDestroyLock: false,
    });
  });
});
