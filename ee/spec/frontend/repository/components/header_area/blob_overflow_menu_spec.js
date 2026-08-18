import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import ceBlobOverflowMenu from '~/repository/components/header_area/blob_overflow_menu.vue';
import BlobOverflowMenu from 'ee_component/repository/components/header_area/blob_overflow_menu.vue';
import BlobButtonGroup from 'ee_else_ce/repository/components/header_area/blob_button_group.vue';
import BlobDeleteFileGroup from '~/repository/components/header_area/blob_delete_file_group.vue';
import {
  blobControlsDataMock,
  refMock,
  getProjectMockWithOverrides,
} from 'ee_else_ce_jest/repository/mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/utils/common_utils', () => ({
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('EE Blob Overflow Menu', () => {
  let wrapper;
  let fakeApollo;

  const projectPath = '/some/project';

  const createComponent = ({ projectInfoResolver, provide = {} } = {}) => {
    fakeApollo = createMockApollo([[projectInfoQuery, projectInfoResolver]]);

    wrapper = shallowMountExtended(BlobOverflowMenu, {
      apolloProvider: fakeApollo,
      provide: {
        blobInfo: blobControlsDataMock.repository.blobs.nodes[0],
        currentRef: refMock,
        rootRef: 'main',
        glLicensedFeatures: {
          fileLocks: true,
        },
        ...provide,
      },
      propsData: {
        isBinary: false,
        isEmptyRepository: false,
        isUsingLfs: false,
        projectPath,
      },
      stubs: {
        ceBlobOverflowMenu,
      },
    });
  };

  const findBlobButtonGroup = () => wrapper.findComponent(BlobButtonGroup);
  const findBlobDeleteFileGroup = () => wrapper.findComponent(BlobDeleteFileGroup);

  describe('canModifyFile', () => {
    beforeEach(() => {
      window.gon.current_user_name = 'root';
    });

    describe('when on default branch', () => {
      it.each`
        scenario                                      | canDestroyPathLock | pathLockNodes | expectedDisabled | expectedIsReplaceDisabled | expectedIsLocked
        ${'user cannot destroy path lock, with lock'} | ${false}           | ${null}       | ${true}          | ${true}                   | ${true}
        ${'user can destroy path lock, with lock'}    | ${true}            | ${null}       | ${false}         | ${false}                  | ${true}
        ${'no lock exists'}                           | ${false}           | ${[]}         | ${false}         | ${false}                  | ${false}
      `(
        'returns correct values when $scenario',
        async ({
          canDestroyPathLock,
          pathLockNodes,
          expectedDisabled,
          expectedIsReplaceDisabled,
          expectedIsLocked,
        }) => {
          const projectInfoResolver = jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: pathLockNodes || [
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
                      destroyPathLock: canDestroyPathLock,
                    },
                  },
                ],
              }),
            },
          });

          createComponent({
            projectInfoResolver,
            provide: { currentRef: 'main' },
          });
          await waitForPromises();

          expect(findBlobDeleteFileGroup().props('disabled')).toBe(expectedDisabled);
          expect(findBlobButtonGroup().props()).toMatchObject({
            canDestroyLock: canDestroyPathLock,
            isReplaceDisabled: expectedIsReplaceDisabled,
            isLocked: expectedIsLocked,
          });
        },
      );
    });

    describe('when not on default branch', () => {
      it.each`
        scenario                                      | canDestroyPathLock | pathLockNodes | expectedDisabled | expectedIsReplaceDisabled | expectedIsLocked
        ${'user cannot destroy path lock, with lock'} | ${false}           | ${null}       | ${false}         | ${false}                  | ${true}
        ${'user can destroy path lock, with lock'}    | ${true}            | ${null}       | ${false}         | ${false}                  | ${true}
        ${'no lock exists'}                           | ${false}           | ${[]}         | ${false}         | ${false}                  | ${false}
      `(
        'returns correct values when $scenario',
        async ({
          canDestroyPathLock,
          pathLockNodes,
          expectedDisabled,
          expectedIsReplaceDisabled,
          expectedIsLocked,
        }) => {
          const projectInfoResolver = jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: pathLockNodes || [
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
                      destroyPathLock: canDestroyPathLock,
                    },
                  },
                ],
              }),
            },
          });

          createComponent({
            projectInfoResolver,
            provide: { currentRef: 'some-other-branch' },
          });
          await waitForPromises();

          expect(findBlobDeleteFileGroup().props('disabled')).toBe(expectedDisabled);
          expect(findBlobButtonGroup().props()).toMatchObject({
            canDestroyLock: canDestroyPathLock,
            isReplaceDisabled: expectedIsReplaceDisabled,
            isLocked: expectedIsLocked,
          });
        },
      );
    });
  });
});
