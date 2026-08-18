import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BlobControls from '~/repository/components/header_area/blob_controls.vue';
import BlobControlsLockButton from 'ee_component/repository/components/header_area/blob_controls_lock_button.vue';
import blobControlsQuery from '~/repository/queries/blob_controls.query.graphql';
import userGitpodInfo from '~/repository/queries/user_gitpod_info.query.graphql';
import applicationInfoQuery from '~/repository/queries/application_info.query.graphql';
import createRouter from '~/repository/router';
import {
  blobControlsDataMock,
  refMock,
  currentUserDataMock,
  applicationInfoMock,
} from 'jest/repository/mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/common_utils', () => ({
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('EE Blob controls component', () => {
  let router;
  let wrapper;
  let fakeApollo;

  const createComponent = async ({ blobControlsResolver } = {}) => {
    const projectPath = 'some/project';
    router = createRouter(projectPath, refMock);

    await router.push({
      name: 'blobPathDecoded',
      params: { path: '/some/file.js' },
    });

    fakeApollo = createMockApollo([
      [
        blobControlsQuery,
        blobControlsResolver ??
          jest.fn().mockResolvedValue({
            data: { project: blobControlsDataMock },
          }),
      ],
      [userGitpodInfo, jest.fn().mockResolvedValue({ data: { currentUser: currentUserDataMock } })],
      [applicationInfoQuery, jest.fn().mockResolvedValue({ data: { ...applicationInfoMock } })],
    ]);

    wrapper = shallowMountExtended(BlobControls, {
      router,
      apolloProvider: fakeApollo,
      provide: {
        currentRef: refMock,
        showWebIdeButton: true,
      },
      propsData: {
        projectPath,
        projectIdAsNumber: 1,
        isBinary: false,
        refType: 'heads',
      },
      stubs: {
        LockButton: BlobControlsLockButton,
      },
    });

    await waitForPromises();
  };

  const findLockButton = () => wrapper.findComponent(BlobControlsLockButton);

  afterEach(() => {
    fakeApollo = null;
  });

  describe('lock button', () => {
    it('renders the lock button once the blob info has loaded', async () => {
      await createComponent();

      expect(findLockButton().exists()).toBe(true);
      expect(findLockButton().props('projectPath')).toBe('some/project');
    });

    it('passes the API-normalized blob path, not the raw route param', async () => {
      await createComponent();

      expect(findLockButton().props('path')).toBe('some/file.js');
    });

    it('does not render the lock button before the blob info has loaded', async () => {
      await createComponent({
        blobControlsResolver: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      expect(findLockButton().exists()).toBe(false);
    });
  });
});
