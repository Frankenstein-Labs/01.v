import { GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BlobDeleteFileGroup from '~/repository/components/header_area/blob_delete_file_group.vue';
import { blobControlsDataMock } from 'ee_else_ce_jest/repository/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/lib/utils/common_utils', () => ({
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

const DEFAULT_PROPS = {
  currentRef: 'master',
  isEmptyRepository: false,
  isUsingLfs: true,
  userPermissions: { pushCode: true, createMergeRequestIn: true, forkProject: true },
  disabled: false,
};

const DEFAULT_INJECT = {
  selectedBranch: 'root-main-patch-07420',
  originalBranch: 'master',
  blobInfo: blobControlsDataMock.repository.blobs.nodes[0],
};

describe('EE blob delete button group', () => {
  let wrapper;
  const createComponent = async ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(BlobDeleteFileGroup, {
      propsData: {
        ...DEFAULT_PROPS,
        ...props,
      },
      provide: {
        ...DEFAULT_INJECT,
      },
    });
    await waitForPromises();
  };

  const findDeleteItem = () => wrapper.findComponent(GlDisclosureDropdownItem);

  describe('disabled prop behavior', () => {
    it.each([
      [true, 'disables the delete button when disabled prop is true'],
      [false, 'enables the delete button when disabled prop is false'],
    ])('when disabled is %s, it %s', async (disabledValue) => {
      await createComponent({
        props: {
          disabled: disabledValue,
        },
      });

      expect(findDeleteItem().props('item')).toMatchObject({
        extraAttrs: { disabled: disabledValue },
      });
    });
  });
});
