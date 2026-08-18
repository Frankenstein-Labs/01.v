import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlobButtonGroup from 'ee/repository/components/header_area/blob_button_group.vue';
import CeBlobButtonGroup from '~/repository/components/header_area/blob_button_group.vue';
import { blobControlsDataMock, refMock } from 'ee_else_ce_jest/repository/mock_data';
import LockFileDropdownItem from 'ee_component/repository/components/header_area/lock_file_dropdown_item.vue';

describe('EE blob button group', () => {
  let wrapper;

  const DEFAULT_PROPS = {
    isUsingLfs: true,
    userPermissions: { pushCode: true, createMergeRequestIn: true, forkProject: true },
    currentRef: refMock,
    isReplaceDisabled: false,
    projectPath: 'some/project/path',
    isLocked: false,
    canCreateLock: true,
    canDestroyLock: true,
    isLoading: false,
  };

  const createComponent = async ({ props = {}, provided = {} } = {}) => {
    wrapper = shallowMountExtended(BlobButtonGroup, {
      propsData: {
        ...DEFAULT_PROPS,
        ...props,
      },
      provide: {
        selectedBranch: 'root-main-patch-07420',
        originalBranch: 'master',
        blobInfo: blobControlsDataMock.repository.blobs.nodes[0],
        glLicensedFeatures: { fileLocks: true },
        ...provided,
      },
      stubs: {
        CeBlobButtonGroup,
        LockFileDropdownItem,
      },
    });
    await waitForPromises();
  };

  const findReplaceItem = () => wrapper.findComponentByTestId('replace-dropdown-item');
  const findLockFileDropdownItem = () => wrapper.findComponent(LockFileDropdownItem);
  const findCeBlobButtonGroup = () => wrapper.findComponent(BlobButtonGroup);

  beforeEach(async () => {
    await createComponent();
  });

  it('passes down properties to the CEWebIdeLink component', () => {
    expect(findCeBlobButtonGroup().props()).toMatchObject({
      isUsingLfs: true,
      userPermissions: { pushCode: true, createMergeRequestIn: true, forkProject: true },
      currentRef: 'default-ref',
      isReplaceDisabled: false,
    });
  });

  it('renders lock file dropdown item', () => {
    expect(findLockFileDropdownItem().exists()).toBe(true);

    expect(findLockFileDropdownItem().props()).toMatchObject({
      name: 'file.js',
      path: 'some/file.js',
      projectPath: 'some/project/path',
      canCreateLock: true,
      canDestroyLock: true,
      isLocked: false,
      isLoading: false,
    });
  });

  describe('when repositoryLockInformation feature flag is enabled', () => {
    it('does not render the lock file dropdown item', async () => {
      await createComponent({
        provided: { glFeatures: { repositoryLockInformation: true } },
      });

      expect(findLockFileDropdownItem().exists()).toBe(false);
    });
  });

  describe('isReplaceDisabled', () => {
    it.each([
      [false, false, 'does not disable replace button when prop is false'],
      [true, true, 'disables replace button when prop is true'],
    ])(
      'when isReplaceDisabled is %s, button disabled state is %s (%s)',
      async (isReplaceDisabled, expectedDisabledState) => {
        if (isReplaceDisabled) {
          await createComponent({ props: { isReplaceDisabled } });
        }

        expect(findReplaceItem().props('item')).toMatchObject({
          text: 'Replace',
          extraAttrs: { disabled: expectedDisabledState, 'data-testid': 'replace' },
        });
      },
    );
  });
});
